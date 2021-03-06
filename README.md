# Alma REST API Ruby library

![Tests](https://github.com/ubpb/alma_api/actions/workflows/tests.yml/badge.svg)
[![Test Coverage](https://api.codeclimate.com/v1/badges/fa479e542383d985dd13/test_coverage)](https://codeclimate.com/github/ubpb/alma_api/test_coverage)
[![Maintainability](https://api.codeclimate.com/v1/badges/fa479e542383d985dd13/maintainability)](https://codeclimate.com/github/ubpb/alma_api/maintainability)
[![Gem Version](https://badge.fury.io/rb/alma_api.svg)](https://badge.fury.io/rb/alma_api)
[![MIT License](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)

This is a simple Ruby library that acts as a wrapper for the
[Ex Libris Alma REST APIs](https://developers.exlibrisgroup.com/alma/apis/).

The main purpose of this library is to abstract authentication, error handling, and response parsing.

It uses [`faraday`](https://github.com/lostisland/faraday) as the underlying http client, [`nokogiri`](https://github.com/sparklemotion/nokogiri) for XML parsing, and [`oj`](https://github.com/ohler55/oj) and [`hashie`](https://github.com/hashie/hashie) for JSON processing.

__Note: This is NOT an official Alma API client. It is developed at the University Library of Paderborn as an open source project.__

## Installation

Add this to your `Gemfile`:

```ruby
gem "alma_api"
```
and run the `bundle install` command in your terminal.

## Usage

> You need an API key for your Alma Instance in order to use this client. Please consult the [Ex Libris developer documentation on how to use the Alma REST APIs](https://developers.exlibrisgroup.com/alma/apis/#using) for more information how to get and setup your API keys.

### Creating a configuration

To use this library you need an `AlmaApi::Client` instance. The client requires an `AlmaApi::Configuration`.

```ruby
configuration = AlmaApi::Configuration.new(
  api_key: "...",        # 1. required
  base_url: "...",       # 2. optional
  default_format: "...", # 3. optional
  language: "..."        # 4. optional
)
```

1. `api_key`
    Add your Alma API key here.
2. `base_url`
    Add the base URL to be used for each request. Ex Libris provides different API gateways for different geographical locations. See [the documentation here](https://developers.exlibrisgroup.com/alma/apis/#calling) for more information. This parameter is optional and defaults to the Alma API Gateway for Europe: `https://api-eu.hosted.exlibrisgroup.com/almaws/v1`.

    You can use a `Symbol` as a shortcut to set the `base_url` for one of the preconfigured gateways `:na` (North America), `:eu` (Europe), `:ap` (Asia-Pacific), `:ca` (Canada), `:cn` (China).

    For example, to set the `base_url` for the canadian gateway, use

    ```ruby
      configuration = AlmaApi::Configuration.new(
        base_url: :ca,
        ...
      )
    ```
3. `default_format`
    The default format to use for each request. The client supports `json` and `xml`. The default is `json`.
4. `language`
    The language used by Alma for error messages and textual information. The default is English (`en`). To change this, set this parameter to any 2-letter language code that is supported and enabled in Alma (see the mapping table "Institution Languages" in Alma).

### Creating a client

With the configuration ready, you can create the client.

```ruby
client = AlmaApi::Client.new(configuration)
```

As a shortcut, you can call `AlmaApi.configure` to get the client instance. Note that each call to `AlmaApi.configure` returns a new `AlmaApi::Client` instance.

```ruby
client = AlmaApi.configure do |config|
  config.api_key = "..."
  config.base_url = "..."
  config.default_format = "..."
  config.language = "..."
end
```
### Using the client

The client provides the following methods: `#get`, `#post`, `#put` and `#delete` to call the Alma APIs with the corresponding HTTP methods `GET`, `POST`, `PUT` and `DELETE`.

Each method expects a URL path to the resource relative to the configured `base_url` as it's first parameter. Parameters that the Alma API expects as part of the URL path must be included here.

To set query string parameters, set the `params:` option and provide a Ruby `hash`. To override the `default_format` for an individual request, you can set the `format:` option to `json` or `xml`, depending on your needs. Setting the format to `xml` is preferable for Alma APIs that work with MARCXML data.

To set the body of a `#post` or `#put` request, you can set the `body:` option. If the request format is `json`, the `body:` option should contain a valid json string. Otherwise, if the request format is `xml`, the option should be a valid XML string.

In the case of a `json` request, the result of the call is a Ruby `hash`. For `xml`, the result is a `Nokogiri::XML::Document` instance, as this library uses [`nokogiri`](https://github.com/sparklemotion/nokogiri) under the hood for XML processing.

## Examples

#### `GET` requests

__Retrieve users__
```ruby
# Retrieve users (JSON)
users = client.get("users", params: {limit: 2})

# Retrieve users (XML)
users = client.get("users", params: {limit: 2}, format: :xml)
```

#### `POST` and `PUT` requests

__Creating a user__
```ruby
# Prepare the data for a new user in Alma
user_data = {
  record_type: {value: "PUBLIC"},
  account_type: {value: "INTERNAL"},
  preferred_language: {value: "de"},
  status: {value: "ACTIVE"},
  first_name: "FIRSTNAME",
  last_name: "LASTNAME",
  birth_date: "1978-07-07",
  [...]
  password: "SECRET PASSWORD",
  force_password_change: true
}

# Create the user in Alma
user = client.post(
  "users",
  params: {
    source_user_id: "xxx"
  },
  body: user_data.to_json
)
```

__Updating a user__
```ruby
# First, get the user
user_id = "..." # a unique identifier for the user
user = client.get("users/#{user_id}") # user_id is a URL parameter

# Change the last name of the user
user["last_name"] = "..."

# Update the user in Alma
user = client.put("users/#{user_id}", body: user.to_json)

```

#### `DELETE` requests

__Deleting a user__
```ruby
user_id = "..." # a unique identifier for the user
client.delete("users/#{user_id}") # user_id is a URL parameter
```

## Error handling

There are three types of errors that can occur when calling the Alma APIs with this library. Each error exposes the `#message` and `#code` methods for further inspection. The message is returned in the language set in the configuration (default is English).

For gateway errors, the code is a string token (e.g. REQUEST_TOO_LARGE). For logical errors, the code is usually a number (e.g. 401850). See the "Possible Error Codes" section for each resource in the [documentation](https://developers.exlibrisgroup.com/alma/apis/) for details.

### 1. `AlmaApi::GatewayError`

If the Alma API responds with a `4xx` OR `5xx` HTTP status AND one of the following error codes, an `AlmaApi::GatewayError` is thrown.

`GENERAL_ERROR`, `UNAUTHORIZED`, `INVALID_REQUEST`, `PER_SECOND_THRESHOLD`, `DAILY_THRESHOLD`, `REQUEST_TOO_LARGE`, `FORBIDDEN`, `ROUTING_ERROR`

Check the [the documentation here](https://developers.exlibrisgroup.com/alma/apis/#error) for more information about gateway errors.

### 2. `AlmaApi::ServerError`

Any `5xx` HTTP status that does not result in an `AlmaApi::GatewayError` will be thrown as an `AlmaApi::ServerError`.

### 3. `AlmaApi::LogicalError`

Any `4xx` HTTP status that does not result in an `AlmaApi::GatewayError` will be thrown as an `AlmaApi::LogicalError`.

This is the most common error you will encounter and can be used to manage the control flow in your application.

For example, if you're loading a user's details, you don't want your application to blow up if a user with the specified user ID doesn't exist. Instead, you can handle the error like this:

```ruby
def load_user(user_id)
  client.get("users/#{user_id}")
rescue AlmaApi::LogicalError => e
  # log the error
  puts "Error #{e.code}: #{e.message}"

  # ... the error code could be inspected and we could perform
  # different things based on the error code but in this case
  # we just return nil to indicate that the user does not exists.
  nil
end

if (user = load_user("ALMA_USER_ID"))
  puts "Hello #{user["first_name"]} #{user["last_name"]}"
else
  puts "Too bad. No such user."
end

```
