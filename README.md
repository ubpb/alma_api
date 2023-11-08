# Alma REST APIs Ruby library

This is a simple Ruby library that acts as wrapper for the
[Ex Libris Alma REST APIs](https://developers.exlibrisgroup.com/alma/apis/).

The main purpose of this library is the abstraction of authentication, error handling and parsing of response data.

It uses [`faraday`](https://github.com/lostisland/faraday) as the underlying http client, [`nokogiri`](https://github.com/sparklemotion/nokogiri) for XML parsing and [`oj`](https://github.com/ohler55/oj) and [`hashie`](https://github.com/hashie/hashie) for JSON processing.

_Note: This is NOT an offical client. It is developed at the University Library of Paderborn as an Open Source project._

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

1. `api_key` Add your Alma API key here.
2. `base_url` Add the base URL that should be used for each request. Ex Libris provides different API Gateways for different geographic locations. Check [the documentation here](https://developers.exlibrisgroup.com/alma/apis/#calling) for more information. This parameter is optional and defaults to the Alma API Gateway for Europe: `https://api-eu.hosted.exlibrisgroup.com/almaws/v1`
3. `default_format` The default format that should be used for each request. The client supports `json` and `xml`. The default is `json`.
4. `language` The language used by Alma for error messages and textual information. By default this is in English (`en`). To change this set this parameter to any 2 letter language code that is supported and activated in Alma (see "Institution Languages" mapping table in Alma).

### Creating a client

With the confiuration ready, you can create the client.
```ruby
client = AlmaApi::Client.new(configuration)
```

As a shortcut you can call `AlmaApi.configure` to get the client instance. Please note that for every call to `AlmaApi.configure` a new `AlmaApi::Client` instance is returned.

```ruby
client = AlmaApi.configure do |config|
  api_key: "...",
  base_url: "...",
  default_format: "...",
  language: "..."
end
```

### Using the client

The client provides the following methods: `#get`, `#post`, `#put`, and `#delete` to call the Alma APIs with the corresponding HTTP methods `GET`, `POST`, `PUT` and `DELETE`.

Each method expects a URL path to the resource relative to the configured `base_url` as it's first parameter. Parameters that the Alma API expects as part of the URL path must be included here.

To set querystring parameters, set the `params:` option and provide a Ruby `Hash`. To override the `default_format` for a single request you can set the `format:` option to `json` or `xml` depending on your needs. Setting the format to `xml` is preferable for Alma APIs that work with MARCXML data.

To set the body of a `#post` or `#put` request, you can set the `body:` option. If the request format is `json` the `body:` option should contain a valid json string. Otherwise, if the request format is `xml` the option should be a valid XML string.

In case of a `json` request the result of a call is a Ruby `Hash`. For `xml` the result is a `Nokogiri::XML::Document` instance as this library uses [`nokogiri`](https://github.com/sparklemotion/nokogiri) under the hood for XML processing.

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

There a three types of errors that may occur when calling the Alma APIs with this library. Each error exposes `#code` and `#message` methods for further inspection.

### `AlmaApi::GatewayError`

If the Alma API responds with a `4xx` or `5xx` HTTP status AND with one of the following error codes, an `AlmaApi::GatewayError` is raised.

`GENERAL_ERROR`, `UNAUTHORIZED`, `INVALID_REQUEST`, `PER_SECOND_THRESHOLD`, `DAILY_THRESHOLD`, `REQUEST_TOO_LARGE`, `FORBIDDEN`, `ROUTING_ERROR`

Check the [the documentation here](https://developers.exlibrisgroup.com/alma/apis/#error) for more information about gateway errors.

### `AlmaApi::ServerError`

Every `5xx` HTTP status that not result in an `AlmaApi::GatewayError` will be raised as an `AlmaApi::ServerError`.

### `AlmaApi::LogicalError`

Every `4xx` HTTP status that not result in an `AlmaApi::GatewayError` will be raised as an `AlmaApi::LogicalError`.

This is the must common error you will be dealing with and can be used to handle control flow in your application.

For example, if you load details of a user you don't want your application to blow up in case a user with the given user ID does't exists. Instead you can handle the error like so

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



