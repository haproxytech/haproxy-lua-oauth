--
-- JWT Validation implementation for HAProxy Lua host
--
-- Copyright (c) 2019. Adis Nezirovic <anezirovic@haproxy.com>
-- Copyright (c) 2019. Baptiste Assmann <bassmann@haproxy.com>
-- Copyright (c) 2019. Nick Ramirez <nramirez@haproxy.com>
-- Copyright (c) 2019. HAProxy Technologies LLC
--
-- Licensed under the Apache License, Version 2.0 (the "License");
-- you may not use this file except in compliance with the License.
-- You may obtain a copy of the License at
--
--    http://www.apache.org/licenses/LICENSE-2.0
--
-- Unless required by applicable law or agreed to in writing, software
-- distributed under the License is distributed on an "AS IS" BASIS,
-- WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
-- See the License for the specific language governing permissions and
-- limitations under the License.
--
-- Use HAProxy 'lua-load' to load optional configuration file which
-- should contain config table.
-- Default/fallback config
if not config then
  config = {
      debug = true,
      publicKey = nil,
      issuer = nil,
      audience = nil,
      hmacSecret = nil
  }
end

-- search these paths for *.lua and *.so files on CentOS/RHEL
package.path = package.path .. ';/usr/local/share/lua/5.3/?.lua'
package.cpath = package.cpath .. ';/usr/local/lib/lua/5.3/?.so;/usr/local/lib/lua/5.3/?/?.so'

local json   = require 'json'
local base64 = require 'base64'
local openssl = {
  pkey = require 'openssl.pkey',
  digest = require 'openssl.digest',
  x509 = require 'openssl.x509',
  hmac = require 'openssl.hmac'
}

local function log(msg)
  if config.debug then
      core.Debug(tostring(msg))
  end
end

local function dump(o)
  if type(o) == 'table' then
     local s = '{ '
     for k,v in pairs(o) do
        if type(k) ~= 'number' then k = '"'..k..'"' end
        s = s .. '['..k..'] = ' .. dump(v) .. ','
     end
     return s .. '} '
  else
     return tostring(o)
  end
end

-- Loops through array to find the given string.
-- items: array of strings
-- test_str: string to search for
local function contains(items, test_str)
  for _,item in pairs(items) do

    -- strip whitespace
    item = item:gsub("%s+", "")
    test_str = test_str:gsub("%s+", "")

    if item == test_str then
      return true
    end
  end

  return false
end

local function readAll(file)
  log("Reading file " .. file)
  local f = assert(io.open(file, "rb"))
  local content = f:read("*all")
  f:close()
  return content
end

local function decodeJwt(authorizationHeader)
  local headerFields = core.tokenize(authorizationHeader, " .")

  if #headerFields ~= 4 then
      log("Improperly formated Authorization header. Should be 'Bearer' followed by 3 token sections.")
      return nil
  end

  if headerFields[1] ~= 'Bearer' then
      log("Improperly formated Authorization header. Missing 'Bearer' property.")
      return nil
  end

  local token = {}
  token.header = headerFields[2]
  token.headerdecoded = json.decode(base64.decode(token.header))

  token.payload = headerFields[3]
  token.payloaddecoded = json.decode(base64.decode(token.payload))

  token.signature = headerFields[4]
  token.signaturedecoded = base64.decode(token.signature)

  log('Decoded JWT header: ' .. dump(token.headerdecoded))
  log('Decoded JWT payload: ' .. dump(token.payloaddecoded))

  return token
end

local function algorithmIsValid(token)
  if token.headerdecoded.alg == nil then
      log("No 'alg' provided in JWT header.")
      return false
  elseif token.headerdecoded.alg ~= 'HS256' and  token.headerdecoded.alg ~= 'HS512' and token.headerdecoded.alg ~= 'RS256' then
      log("HS256, HS512 and RS256 supported. Incorrect alg in JWT: " .. token.headerdecoded.alg)
      return false
  end

  return true
end

local function rs256SignatureIsValid(token, publicKey)
  local digest = openssl.digest.new('SHA256')
  digest:update(token.header .. '.' .. token.payload)
  local vkey = openssl.pkey.new(publicKey)
  local isVerified = vkey:verify(token.signaturedecoded, digest)
  return isVerified
end

local function hs256SignatureIsValid(token, secret)
  local hmac = openssl.hmac.new(secret, 'SHA256')
  local checksum = hmac:final(token.header .. '.' .. token.payload)
  return checksum == token.signaturedecoded
end

local function hs512SignatureIsValid(token, secret)
  local hmac = openssl.hmac.new(secret, 'SHA512')
  local checksum = hmac:final(token.header .. '.' .. token.payload)
  return checksum == token.signaturedecoded
end

local function expirationIsValid(token)
  return os.difftime(token.payloaddecoded.exp, core.now().sec) > 0
end

local function issuerIsValid(token, expectedIssuer)
  return token.payloaddecoded.iss == expectedIssuer
end

-- Checks if the audience in the token is listed in the
-- OAUTH_AUDIENCE environment variable. Both the token audience
-- and the environment variable can contain multiple audience values, 
-- separated by commas. Each value will be checked.
local function audienceIsValid(token, expectedAudienceParam)
  
  -- Convert OAUTH_AUDIENCE environment variable to a table,
  -- even if it contains only one value
  local expectedAudiences = expectedAudienceParam
  if type(expectedAudiences) == "string" then
    -- split multiple values using a space as the delimiter
    expectedAudiences = core.tokenize(expectedAudienceParam, " ")
  end

  -- Convert 'aud' claim to a table, even if it contains only one value
  local receivedAudiences = token.payloaddecoded.aud
  if type(token.payloaddecoded.aud) == "string" then
    receivedAudiences ={}
    receivedAudiences[1] = token.payloaddecoded.aud
  end

  for _, receivedAudience in ipairs(receivedAudiences) do
    if contains(expectedAudiences, receivedAudience) then
      return true
    end
  end

  return false
end

local function setVariablesFromPayload(txn, decodedPayload)
  for key, value in pairs(decodedPayload) do
    txn:set_var("txn.oauth." .. key, dump(value))
  end
end

local function jwtverify(txn)
  local pem = config.publicKey
  local issuer = config.issuer
  local audience = config.audience
  local hmacSecret = config.hmacSecret

  -- 1. Decode and parse the JWT
  local token = decodeJwt(txn.sf:req_hdr("Authorization"))

  if token == nil then
    log("Token could not be decoded.")
    goto out
  end

  -- Set an HAProxy variable for each field in the token payload
  setVariablesFromPayload(txn, token.payloaddecoded)

  -- 2. Verify the signature algorithm is supported (HS256, HS512, RS256)
  if algorithmIsValid(token) == false then
      log("Algorithm not valid.")
      goto out
  end

  -- 3. Verify the signature with the certificate
  if token.headerdecoded.alg == 'RS256' then
    if rs256SignatureIsValid(token, pem) == false then
      log("Signature not valid.")
      goto out
    end
  elseif token.headerdecoded.alg == 'HS256' then
    if hs256SignatureIsValid(token, hmacSecret) == false then
      log("Signature not valid.")
      goto out
    end
  elseif token.headerdecoded.alg == 'HS512' then
    if hs512SignatureIsValid(token, hmacSecret) == false then
      log("Signature not valid.")
      goto out
    end
  end

  -- 4. Verify that the token is not expired
  if expirationIsValid(token) == false then
    log("Token is expired.")
    goto out
  end

  -- 5. Verify the issuer
  if issuer ~= nil and issuerIsValid(token, issuer) == false then
    log("Issuer not valid.")
    goto out
  end

  -- 6. Verify the audience
  if audience ~= nil and audienceIsValid(token, audience) == false then
    log("Audience not valid.")
    goto out
  end

  -- 8. Set authorized variable
  log("req.authorized = true")
  txn.set_var(txn, "txn.authorized", true)

  -- exit
  do return end

  -- way out. Display a message when running in debug mode
::out::
 log("req.authorized = false")
 txn.set_var(txn, "txn.authorized", false)
end

-- Called after the configuration is parsed.
-- Loads the OAuth public key for validating the JWT signature.
core.register_init(function()
  config.issuer = os.getenv("OAUTH_ISSUER")
  config.audience = os.getenv("OAUTH_AUDIENCE")
  
  -- when using an RS256 signature
  local publicKeyPath = os.getenv("OAUTH_PUBKEY_PATH") 
  local pem = readAll(publicKeyPath)
  config.publicKey = pem
  
  -- when using an HS256 or HS512 signature
  config.hmacSecret = os.getenv("OAUTH_HMAC_SECRET")
  
  log("PublicKeyPath: " .. publicKeyPath)
  log("Issuer: " .. (config.issuer or "<none>"))
  log("Audience: " .. (config.audience or "<none>"))
end)

-- Called on a request.
core.register_action('jwtverify', {'http-req'}, jwtverify, 0)
