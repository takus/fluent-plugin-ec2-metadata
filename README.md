# fluent-plugin-ec2-metadata

Fluentd plugin to add ec2 metadata fields to a event record

## Installation
Use RubyGems:

    gem install fluent-plugin-ec2-metadata

## Configuration

Example:

    <match foo.**>
      type ec2-metadata
      output_tag ${instance_id}.${tag}

      <record>
        hostname ${instance_id}
      </record>
    </match>

Assume following input is coming:

```js
foo.bar {"message":"hello ec2!"}
```

then output becomes as below (indented):

```js
i-28b5ee77.foo.bar {
  "hostname" : "i-28b5ee77",
  "message"  : "hello ec2!"
}
```

### Placeholders

The following placeholders are available:

* ${instance_id} instance id
* ${tag} input tag
* ${tag_parts} input tag splitted by '.'. you can use it like `${tag_parts[0]}` or `${tag_parts[-1]`

## Contributing

1. Fork it
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request
