# OmniAuth Azure DevOps Strategy

OmniAuth Azure DevOps is a Ruby gem that provides authentication for your Ruby applications via the Azure DevOps OAuth 2.0 authentication system.

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'omniauth-azure-devops'
```

And then execute:

```bash
bundle install
```

## Usage

1. Register your application with Azure DevOps to obtain the `AZURE_DEVOPS_CLIENT_ID` and `AZURE_DEVOPS_CLIENT_SECRET` credentials.

2. In your application configuration, add the following line to use the Azure DevOps OmniAuth strategy:

   ```ruby
   provider :azure_devops, ENV['AZURE_DEVOPS_CLIENT_ID'], ENV['AZURE_DEVOPS_CLIENT_SECRET'], scope: 'vso.auditlog etc...', callback_path: '/link/azure_devops/oauth_callback'
   ```

   Replace `ENV['AZURE_DEVOPS_CLIENT_ID']` and `ENV['AZURE_DEVOPS_CLIENT_SECRET']` with your Azure DevOps client credentials.

3. Implement the necessary routes and views to initiate the authentication process and handle the callback.

4. When users access the authentication route, they will be redirected to Azure DevOps for authentication. After successful authentication, Azure DevOps will redirect them back to your specified callback URL.

5. Access user information and tokens as needed in your application by utilizing the OmniAuth authentication data.

### Microsoft Entra ID

The `azure_devops_entra` strategy signs users in through a multi-tenant Microsoft Entra ID application (authorization code + PKCE) and authenticates the code exchange with a certificate-signed client assertion, so no client secret is used.

```ruby
provider :azure_devops_entra, ENV['ENTRA_APP_ID'], nil,
         client_private_key: ENV['ENTRA_CLIENT_PRIVATE_KEY'],
         certificate_thumbprint: ENV['ENTRA_CERTIFICATE_THUMBPRINT'],
         scope: '499b84ac-1321-427f-aa17-267ca6975798/.default offline_access',
         callback_path: '/link/azure_devops_entra/oauth_callback'
```

- `client_private_key` is the PEM private key of the certificate registered on the Entra application, and `certificate_thumbprint` is its base64url-encoded SHA-1 thumbprint (the JWT `x5t` header).
- `scope` is sent exactly as given. Include `offline_access`, or Entra issues no refresh token.
- The auth hash `uid` is the Azure DevOps profile id, the same value the `azure_devops` strategy returns. `extra.tenant_id` is the user's Entra tenant id, which is needed to refresh the token later at `https://login.microsoftonline.com/{tenant_id}/oauth2/v2.0/token`.

## Running Tests

You can run the test suite using the following command:

```bash
rake spec
```

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake spec` to run the spec. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`.

## Contributing

Bug reports and pull requests are welcome on GitHub at [https://github.com/rewindio/omniauth-azure-devops](https://github.com/rewindio/omniauth-azure-devops). This project is intended to be a safe, welcoming space for collaboration, and contributors are expected to adhere to the [Contributor Covenant](https://www.contributor-covenant.org) code of conduct.

## License

This gem is available as open-source software under the [MIT License](https://opensource.org/licenses/MIT).
