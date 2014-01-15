# fluent-plugin-ec2-metadata

Fluentd plugin to add ec2 metadata fields to a event record

## Installation

Use RubyGems:

    gem install fluent-plugin-ec2-metadata

## Configuration

Example:

    <match foo.**>
      type ec2-metadata
      output_tag ec2.foo.bar
      add_fields instance_id,instance_type,availability_zone,ami_id
    </match>

Assume following input is coming:

```js
foo.bar {"message":"hello aws!"}
```

then output becomes as below (indented):

```js
ec2.foo.bar {
  "message"           : "hello aws!",
  "availability_zone" : "us-west-1b",
  "instance_id"       : "i-28b5ee77",
  "instance_type"     : "m1.large",
}
```

### add_fields

The following keys are available:

* **ami_id** ami id
* **availability_zone** availability zone
* **instance_id** instance id
* **instance_type** instance_type

## Contributing

1. Fork it
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request
