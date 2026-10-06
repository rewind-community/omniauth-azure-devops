# frozen_string_literal: true

describe OmniAuth::Strategies::AzureDevopsEntra do
  let(:client_id) { 'b5c0d1a2-0000-4000-8000-000000000001' }
  let(:private_key) { OpenSSL::PKey::RSA.new(2048) }
  let(:certificate_thumbprint) { 'q5V2NvbdLEmbHE3uu_N1lFNmzWs' }
  let(:strategy_options) { { client_private_key: private_key.to_pem, certificate_thumbprint: certificate_thumbprint } }
  let(:strategy) { described_class.new(nil, client_id, nil, strategy_options) }
  let(:request) do
    instance_double('Request', params: {}, scheme: 'https', url: '/auth/azure_devops_entra/callback',
                               query_string: 'code=auth-code&state=abc', env: { 'rack.input' => StringIO.new })
  end
  let(:token_url) { 'https://login.microsoftonline.com/organizations/oauth2/v2.0/token' }

  before do
    allow(strategy).to receive(:request).and_return(request)
  end

  def decode_assertion(assertion)
    JWT.decode(assertion, private_key.public_key, true, algorithm: 'RS256', aud: token_url, verify_aud: true)
  end

  describe '#client' do
    it 'calls the Azure DevOps API on the VSSPS host' do
      expect(strategy.client.site).to eq('https://app.vssps.visualstudio.com')
    end

    it 'authorizes against the multi-tenant Entra endpoint' do
      expect(strategy.client.options[:authorize_url]).to eq('https://login.microsoftonline.com/organizations/oauth2/v2.0/authorize')
    end

    it 'redeems tokens at the multi-tenant Entra endpoint' do
      expect(strategy.client.options[:token_url]).to eq(token_url)
    end

    it 'does not authenticate the client with a secret' do
      expect(strategy.client.options[:auth_scheme]).to eq(:private_key_jwt)
    end
  end

  describe '#authorize_params' do
    it 'forces the account picker' do
      expect(strategy.authorize_params[:prompt]).to eq('select_account')
    end

    it 'sends an S256 PKCE challenge for the stored verifier' do
      params = strategy.authorize_params
      verifier = strategy.session['omniauth.pkce.verifier']

      expect(params[:code_challenge_method]).to eq('S256')
      expect(params[:code_challenge]).to eq(Base64.urlsafe_encode64(Digest::SHA2.digest(verifier), padding: false))
    end

    it 'does not send the legacy request_type' do
      expect(strategy.authorize_params).not_to have_key(:request_type)
    end

    context 'when a scope is configured' do
      let(:scope) { '499b84ac-1321-427f-aa17-267ca6975798/vso.code offline_access' }
      let(:strategy_options) { { scope: scope } }

      it 'requests exactly that scope' do
        expect(strategy.authorize_params[:scope]).to eq(scope)
      end
    end
  end

  describe '#token_params' do
    before { strategy.authorize_params }

    it 'identifies the client in the body' do
      expect(strategy.token_params[:client_id]).to eq(client_id)
    end

    it 'has the correct client_assertion_type' do
      expect(strategy.token_params[:client_assertion_type]).to eq('urn:ietf:params:oauth:client-assertion-type:jwt-bearer')
    end

    it 'signs the client assertion with the certificate key and thumbprint' do
      _claims, header = decode_assertion(strategy.token_params[:client_assertion])

      expect(header).to include('alg' => 'RS256', 'typ' => 'JWT', 'x5t' => certificate_thumbprint)
    end

    it 'issues a short-lived client assertion for this client' do
      claims, = decode_assertion(strategy.token_params[:client_assertion])

      expect(claims).to include('iss' => client_id, 'sub' => client_id, 'aud' => token_url)
      expect(claims['exp'] - claims['iat']).to eq(120)
      expect(claims['nbf']).to eq(claims['iat'])
      expect(claims['jti']).to match(/\A\h{8}-\h{4}-\h{4}-\h{4}-\h{12}\z/)
    end

    it 'sends the PKCE verifier' do
      verifier = strategy.session['omniauth.pkce.verifier']

      expect(strategy.token_params[:code_verifier]).to eq(verifier)
    end
  end

  describe 'authorization code exchange' do
    let(:strategy) { described_class.new(nil, client_id, 'configured-secret', strategy_options) }
    let(:stubs) { Faraday::Adapter::Test::Stubs.new }
    let(:token_request) { {} }
    let(:graph_token_request) { {} }
    let(:graph_url) { 'https://graph.microsoft.com/v1.0/organization' }
    let(:token_response) do
      { access_token: JWT.encode({ 'tid' => 'tenant-guid' }, nil, 'none'), refresh_token: 'refresh-1', expires_in: 5219, token_type: 'Bearer' }
    end

    before do
      allow(request).to receive(:params).and_return({ 'code' => 'auth-code', 'state' => 'abc' })
      allow(OAuth2::Client).to receive(:new).and_wrap_original do |original, *args|
        original.call(*args) do |builder|
          builder.request :url_encoded
          builder.adapter :test, stubs
        end
      end
      stubs.post(token_url) do |env|
        body = URI.decode_www_form(env.body).to_h
        recorded = body['grant_type'] == 'refresh_token' ? graph_token_request : token_request
        recorded[:headers] = env.request_headers
        recorded[:body] = body
        response = body['grant_type'] == 'refresh_token' ? { access_token: 'graph-token', token_type: 'Bearer', expires_in: 3600 } : token_response
        [200, { 'Content-Type' => 'application/json' }, JSON.generate(response)]
      end
      strategy.authorize_params
      strategy.access_token = strategy.send(:build_access_token)
    end

    it 'sends no secret or Basic credentials even when a secret is configured' do
      expect(token_request[:headers]).not_to have_key('Authorization')
      expect(token_request[:body]).not_to have_key('client_secret')
    end

    it 'redeems the code with PKCE and the client assertion' do
      expect(token_request[:body]).to include('grant_type' => 'authorization_code', 'code' => 'auth-code', 'client_id' => client_id,
                                              'redirect_uri' => '/auth/azure_devops_entra/callback')
      expect(token_request[:body]['code_verifier']).to match(/\A\h{128}\z/)
      expect(decode_assertion(token_request[:body]['client_assertion']).first).to include('iss' => client_id)
    end

    it 'returns the refresh token in the credentials' do
      expect(strategy.credentials['refresh_token']).to eq('refresh-1')
    end

    it 'reads the tenant name from Microsoft Graph' do
      stubs.get(graph_url) { [200, { 'Content-Type' => 'application/json' }, JSON.generate(value: [{ displayName: 'Contoso Ltd' }])] }

      expect(strategy.tenant_name).to eq('Contoso Ltd')
    end

    it 'redeems the refresh token for a User.Read token with the client assertion' do
      stubs.get(graph_url) { [200, { 'Content-Type' => 'application/json' }, JSON.generate(value: [{ displayName: 'Contoso Ltd' }])] }
      strategy.tenant_name

      expect(graph_token_request[:body]).to include('grant_type' => 'refresh_token', 'refresh_token' => 'refresh-1', 'client_id' => client_id,
                                                    'scope' => 'https://graph.microsoft.com/User.Read')
      expect(graph_token_request[:body]).not_to have_key('client_secret')
      expect(graph_token_request[:headers]).not_to have_key('Authorization')
      expect(decode_assertion(graph_token_request[:body]['client_assertion']).first).to include('iss' => client_id)
    end

    it 'has no tenant name when Microsoft Graph refuses' do
      stubs.get(graph_url) { [403, { 'Content-Type' => 'application/json' }, JSON.generate(error: { code: 'Authorization_RequestDenied' })] }

      expect(strategy.tenant_name).to be_nil
    end

    it 'logs why the tenant name is missing' do
      stubs.get(graph_url) { [403, { 'Content-Type' => 'application/json' }, JSON.generate(error: { code: 'Authorization_RequestDenied' })] }
      allow(OmniAuth.logger).to receive(:warn)

      strategy.tenant_name

      expect(OmniAuth.logger).to have_received(:warn).with(a_string_including('tenant-guid', 'OAuth2::Error', 'status 403'))
    end
  end

  describe '#uid' do
    let(:access_token) do
      instance_double('AccessToken', token: JWT.encode({ 'oid' => 'a0000000-0000-4000-8000-0000000000aa' }, nil, 'none'),
                                     get: instance_double('Response', parsed: { 'id' => 'b0000000-0000-4000-8000-0000000000bb' }))
    end

    before do
      allow(strategy).to receive(:access_token).and_return(access_token)
    end

    it 'is the Azure DevOps profile id, not the Entra object id' do
      expect(strategy.uid).to eq('b0000000-0000-4000-8000-0000000000bb')
    end
  end

  describe '#info' do
    let(:raw_info) { { 'display_name' => 'John Doe', 'email_address' => 'john.doe@example.com' } }

    before do
      allow(strategy).to receive(:raw_info).and_return(raw_info)
    end

    it 'returns the correct name' do
      expect(strategy.info[:name]).to eq('John Doe')
    end

    it 'returns the correct email address' do
      expect(strategy.info[:email_address]).to eq('john.doe@example.com')
    end
  end

  describe '#extra' do
    let(:raw_info) { { 'id' => '123' } }

    before do
      allow(strategy).to receive_messages(raw_info: raw_info, tenant_id: 'tenant-guid', tenant_name: 'Contoso Ltd')
    end

    it 'includes the raw_info' do
      expect(strategy.extra[:raw_info]).to eq(raw_info)
    end

    it 'includes the tenant id' do
      expect(strategy.extra[:tenant_id]).to eq('tenant-guid')
    end

    it 'includes the tenant name' do
      expect(strategy.extra[:tenant_name]).to eq('Contoso Ltd')
    end
  end

  describe '#tenant_id' do
    let(:access_token) { instance_double('AccessToken', token: JWT.encode({ 'tid' => 'c0000000-0000-4000-8000-0000000000cc' }, 'other-key', 'HS256')) }

    before do
      allow(strategy).to receive(:access_token).and_return(access_token)
    end

    it 'reads the tid claim from the access token' do
      expect(strategy.tenant_id).to eq('c0000000-0000-4000-8000-0000000000cc')
    end
  end

  describe '#raw_info' do
    let(:profile) { { 'id' => '123', 'display_name' => 'John Doe', 'email_address' => 'john.doe@example.com' } }
    let(:access_token) { instance_double('AccessToken', get: instance_double('Response', parsed: profile)) }

    before do
      allow(strategy).to receive(:access_token).and_return(access_token)
    end

    it 'fetches the Azure DevOps profile' do
      expect(strategy.raw_info).to eq(profile)
      expect(access_token).to have_received(:get).with('/_apis/profile/profiles/me', params: { 'api-version' => '7.1' })
    end
  end

  describe '#callback_path' do
    it 'has the correct callback path' do
      expect(strategy.callback_path).to eq('/auth/azure_devops_entra/callback')
    end
  end

  describe '#callback_url' do
    it 'omits the callback query string' do
      expect(strategy.callback_url).to eq('/auth/azure_devops_entra/callback')
    end
  end
end
