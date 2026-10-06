# frozen_string_literal: true

require 'json'
require 'jwt'
require 'openssl'
require 'securerandom'
require 'omniauth/strategies/oauth2'

module OmniAuth
  module Strategies
    class AzureDevopsEntra < OmniAuth::Strategies::OAuth2
      TOKEN_URL = 'https://login.microsoftonline.com/organizations/oauth2/v2.0/token'
      CLIENT_ASSERTION_TYPE = 'urn:ietf:params:oauth:client-assertion-type:jwt-bearer'
      CLIENT_ASSERTION_LIFETIME_SECONDS = 120
      GRAPH_SCOPE = 'https://graph.microsoft.com/User.Read'
      GRAPH_ORGANIZATION_URL = 'https://graph.microsoft.com/v1.0/organization'

      option :name, :azure_devops_entra
      option :pkce, true
      option :client_private_key, nil
      option :certificate_thumbprint, nil

      option :client_options, {
        site: 'https://app.vssps.visualstudio.com',
        authorize_url: 'https://login.microsoftonline.com/organizations/oauth2/v2.0/authorize',
        token_url: TOKEN_URL,
        auth_scheme: :private_key_jwt
      }

      option :authorize_params, {
        prompt: 'select_account'
      }

      # Must stay the ADO profile id, never the token's `oid` claim: they are different GUIDs, and rewind-app finds the
      # existing service instance by `platform_id: uid`, so an `oid` here silently creates a second instance.
      uid { raw_info['id'] }

      info do
        {
          name: raw_info['display_name'],
          email_address: raw_info['email_address']
        }
      end

      extra do
        {
          raw_info: raw_info,
          tenant_id: tenant_id,
          tenant_name: tenant_name
        }
      end

      def raw_info
        @raw_info ||= access_token.get('/_apis/profile/profiles/me', params: { 'api-version' => '7.1' }).parsed
      end

      def tenant_id
        @tenant_id ||= JWT.decode(access_token.token, nil, false).first['tid']
      end

      def tenant_name
        return @tenant_name if defined?(@tenant_name)

        @tenant_name = JSON.parse(graph_access_token.get(GRAPH_ORGANIZATION_URL).body).dig('value', 0, 'displayName')
      rescue StandardError => e
        status = e.response&.status if e.is_a?(::OAuth2::Error)
        log :warn, "Could not read the Entra tenant name for tenant #{tenant_id}: #{e.class} (status #{status.inspect}): #{e.message}"
        @tenant_name = nil
      end

      def token_params
        super.tap do |params|
          params[:client_id] = client.id
          params[:client_assertion_type] = CLIENT_ASSERTION_TYPE
          params[:client_assertion] = client_assertion
        end
      end

      def callback_url
        full_host + callback_path
      end

      private

      def graph_access_token
        client.get_token(
          grant_type: 'refresh_token',
          refresh_token: access_token.refresh_token,
          scope: GRAPH_SCOPE,
          client_id: client.id,
          client_assertion_type: CLIENT_ASSERTION_TYPE,
          client_assertion: client_assertion
        )
      end

      def client_assertion
        now = Time.now.to_i
        claims = {
          iss: client.id,
          sub: client.id,
          aud: TOKEN_URL,
          jti: SecureRandom.uuid,
          exp: now + CLIENT_ASSERTION_LIFETIME_SECONDS,
          nbf: now,
          iat: now
        }

        JWT.encode(claims, OpenSSL::PKey::RSA.new(options.client_private_key), 'RS256',
                   { alg: 'RS256', typ: 'JWT', x5t: options.certificate_thumbprint })
      end
    end
  end
end
