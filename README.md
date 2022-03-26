# OAuth 2 library for HAProxy

This is a Lua library for HAProxy that will verify OAuth 2 JWT tokens.

## Install

The `jwtverify.lua` file has these dependencies:

* base64 (included in this repository)
* [lua-json](https://github.com/rxi/json.lua)
* [luaossl](https://github.com/wahern/luaossl)
* [luasocket](https://github.com/diegonehab/luasocket)

Install like so:

```
git clone https://github.com/haproxytech/haproxy-lua-oauth.git
cd haproxy-lua-oauth
chmod +x ./install.sh
sudo ./install.sh luaoauth
```

This installs jwtverify.lua and its dependencies to **/usr/local/share/lua/5.3/jwtverify.lua**.

## Usage

1. Sign up for an account with an OAuth token provider, such as https://auth0.com
1. Create a new API on the Auth0 website
1. Create a new "Machine to Machine Application" on the Auth0 website, optionally granting it "scopes"
1. Download the public key certificate for your application on the Auth0 website via *Applications > My App > Settings > Show Advanced Settings > Certificates > Download Certificate*. Auth0 signs tokens using this key. Convert it  using `openssl x509 -pubkey -noout -in ./mycert.pem > pubkey.pem`.
1. Update the HAProxy configuration file by:
    * Copy *haproxy-example.cfg* to **/etc/haproxy/haproxy.cfg** and restart HAProxy via `sudo systemctl restart haproxy`
    * *or* run it from this directory via `sudo haproxy -f ./haproxy-example.cfg`
1. Get a JSON web token (JWT) from your authentication server by following the *Quick Start* on the Auth0 website, under the Applications tab, for your Machine to Machine application.
1. Make requests to your API and attach the JWT in the Authorization header. You should get a successful response.

## Supported Signing Algorithms

* RS256
* HS256
* HS512

## Support for multiple audiences

This library support specifying multiple audience values in the JWT token. They should be specified as a JSON array of strings.
You can also accept multiple audience values in the `OAUTH_AUDIENCE` environment variable in the **haproxy.cfg** file. Separate each value
with a space and surround it with double quotes:

```
setenv OAUTH_AUDIENCE "https://api.mywebsite.com https://api2.mywebsite.com"
```

## Output variables

After calling `http-request lua.jwtverify`, you get access to variables for each of the claims in the token.

*Examples*

* `var(txn.oauth.aud)`
* `var(txn.oauth.clientId)`
* `var(txn.oauth.iss)`
* `var(txn.oauth.scope)`

For example, you could track rate limiting based on the clientId or set different rate limit thresholds based on the scope.

## Example

Try it out using the Docker Compose.

1. Sign up for a free account at https://auth0.com/ and create a new API.
1. Give the API any name, such as "My OAuth Test" and set the identifier to "https://api.mywebsite.com".
1. Once created, go to the API's "Permissions" tab and add permissions (aka scopes) that grant users different levels of access. The colon syntax is just a personal style, and colons do not mean anything special.

   | permission  | description           |
   |-------------|-----------------------|
   | read:myapp  | Read access to my app |
   | write:myapp | Write access to myapp | 

1. Now that you have an API defined in Auth0, add an application that is allowed to authenticate to it. Go to the "Applications" tab and add a new "Machine to Machine Application" and select the API you just created. Give it the "read:myapp" and "write:myapp"permissions (or only one or the other).
1. On the Settings page for the new application, go to **Advanced Settings > Certificates** and download the certificate in PEM format. HAProxy will validate the access tokens against this certificate, which was signed by the OAuth provider, Auth0.

1. Convert it first using `openssl x509 -pubkey -noout -in ./mycert.pem > pubkey.pem` and save **pubkey.pem** to **/example/haproxy/pem/pubkey.pem**.
1. Edit **example/haproxy/haproxy.cfg**: 

   * replace the `OAUTH_ISSUER` variable in the global section with the Auth0 domain URL with your own, such as https://myaccount.auth0.com/. 
   * replace the `OAUTH_AUDIENCE` variable with your API name in Auth0, such as "https://api.mywebsite.com". 
   * replace the `OAUTH_PUBKEY_PATH` variable with the path to your PEM certificate. (also update the docker-compose file)

1. Create the environment with Docker Compose:
    ```
    $ docker-compose -f docker-compose.ubuntu.example.yml build
    $ docker-compose -f docker-compose.ubuntu.example.yml up
    ```
1. Get a JSON web token (JWT) from your authentication server by going to your application on the Auth0 website and following the *Quick Start*.
1. Make requests to https://localhost/api/myapp and attach the JWT in the Authorization header. You should get a successful response.

   ```
   $ curl --request GET \
      -k \
      --url https://localhost/api/myapp \
      --header 'authorization: Bearer eyJhbGciOiJSUzI1NiIsInR5cCI6IkpXVCIsImtpZCI6IlJEVkNSVFZHTmpZNU5rVTJSVUV3TnpoRk56UkJRalU0TjBFeU5EWTNSRU01TWtaRFJqTkNNUSJ9.eyJpc3MiOiJodHRwczovL25pY2tyYW00NC5hdXRoMC5jb20vIiwic3ViIjoicm9DTHRDTlZycW0zNmVYTzJxcE84cjEzeFBmQno1NklAY2xpZW50cyIsImF1ZCI6Imh0dHBzOi8vYXBpLm15d2Vic2l0ZS5jb20iLCJpYXQiOjE2NDgzMTQ2NjAsImV4cCI6MTY0ODQwMTA2MCwiYXpwIjoicm9DTHRDTlZycW0zNmVYTzJxcE84cjEzeFBmQno1NkkiLCJzY29wZSI6InJlYWQ6bXlhcHAgd3JpdGU6bXlhcHAiLCJndHkiOiJjbGllbnQtY3JlZGVudGlhbHMifQ.tEhJ0hKlqy9KRrS00we1Z6Y0CwGg5tAOmZ3qQYLYEwl1uymZ8OfJD9iGgPe5QhLJCTD-iwC18hWSwBMzNRLrjcjp1__hHOOyJRRoqekezS7NoHCMOKGLRis5EcfXMyb58yVxwrKIovHSRaEf0emg5NovQ2bdI3UpMThXnzlLhIH_SX5yRUtTxQ_qvO7xS9lZBNVYG9lYlNtU_Ih6dKCKNRUrMm8xsj2jLyR5_v3LcxgwzhK2VF01DZ9wyEgfHgs3H2AP6yJEZkmd9B1chO5Xf3f4klujsxvAb6RqTCwpGWmjRPY6SENkY2QX-PHOYVAc4zPvuauwx9Ojd4khA_KKfA'
   ```

   A successful response:

   ```
   ["robo-hamster","space-hamster","commando-hamster","pirate-hmaster"]
   ```