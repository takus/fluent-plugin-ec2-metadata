# fluent-plugin-ec2-metadata, a plugin for [Fluentd](http://fluentd.org)

Fluentd plugin to add ec2 metadata fields to a event record

## Installation
Use RubyGems:

    gem install fluent-plugin-ec2-metadata

## Configuration

Example:

    <match foo.**>
      type ec2_metadata

      aws_key_id  YOUR_AWS_KEY_ID
      aws_sec_key YOUR_AWS_SECRET/KEY

      output_tag ${instance_id}.${tag}
      <record>
        hostname      ${tagset_name}
        instance_id   ${instance_id}
        instance_type ${instance_type}
        az            ${availability_zone}
        vpc_id        ${vpc_id}
      </record>
    </match>

Assume following input is coming:

```js
foo.bar {"message":"hello ec2!"}
```

then output becomes as below (indented):

```js
i-28b5ee77.foo.bar {
  "hostname"      : "web0001",
  "instance_id"   : "i-28b5ee77",
  "instance_type" : "m1.large",
  "az"            : "us-west-1b",
  "vpc_id"        : "vpc-25dab194",
  "message"       : "hello ec2!"
}
```

### Placeholders

The following placeholders are always available:

* ${tag} input tag
* ${tag_parts} input tag splitted by '.'. you can use it like `${tag_parts[0]}` or `${tag_parts[-1]}`
* ${instance_id} instance id
* ${instance_type} instance type
* ${availability_zone} availability zone
* ${region} region

The followings are available when you define `aws_key_id` and `aws_sec_key`(or Define IAM Policy):

* ${vpc_id} vpc id
* ${subnet_id} subnet id
* ${tagset_xxx} EC2 tag (e.g. tagset_name is replaced by the value of Key = Name)

### IAM Policy

The following is an example for a minimal IAM policy needed to ReadOnlyAccess to EC2.

```
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": "ec2:Describe*",
      "Resource": "*"
    },
    {
      "Effect": "Allow",
      "Action": "elasticloadbalancing:Describe*",
      "Resource": "*"
    },
    {
      "Effect": "Allow",
      "Action": [
        "cloudwatch:ListMetrics",
        "cloudwatch:GetMetricStatistics",
        "cloudwatch:Describe*"
      ],
      "Resource": "*"
    },
    {
      "Effect": "Allow",
      "Action": "autoscaling:Describe*",
      "Resource": "*"
    }
  ]
}
```

Refer to the {AWS documentation}[http://docs.aws.amazon.com/IAM/latest/UserGuide/ExampleIAMPolicies.html] for example policies.
Using {IAM roles}[http://docs.aws.amazon.com/IAM/latest/UserGuide/WorkingWithRoles.html] with a properly configured IAM policy are preferred over embedding access keys on EC2 instances.

## Contributing

1. Fork it
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request
