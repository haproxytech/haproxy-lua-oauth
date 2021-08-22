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

You have several installation modes:

| Command                   | Meaning                                                                                   |
|---------------------------|-------------------------------------------------------------------------------------------|
| `sudo install.sh luaoauth`  | Installs jwtverify.lua and its dependencies to **/usr/local/share/lua/5.3/jwtverify.lua** |
| `sudo install.sh haproxy` | Installs HAProxy                                                                          |
| `sudo install.sh all`     | Installs HAProxy and jwtverify.lua and its dependencies                                   |

## Sample

A sample application can be found at https://github.com/haproxytechblog/haproxy-jwt-vagrant.

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
