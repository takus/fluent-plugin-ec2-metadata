# fluent-plugin-ec2-metadata

[![Gem Version](https://badge.fury.io/rb/fluent-plugin-ec2-metadata.svg)](http://badge.fury.io/rb/fluent-plugin-ec2-metadata)
[![Build Status](https://travis-ci.org/takus/fluent-plugin-ec2-metadata.svg?branch=master)](https://travis-ci.org/takus/fluent-plugin-ec2-metadata)
[![Test Coverage](https://codeclimate.com/github/takus/fluent-plugin-ec2-metadata/badges/coverage.svg)](https://codeclimate.com/github/takus/fluent-plugin-ec2-metadata/coverage)
[![Code Climate](https://codeclimate.com/github/takus/fluent-plugin-ec2-metadata/badges/gpa.svg)](https://codeclimate.com/github/takus/fluent-plugin-ec2-metadata)
[![Codacy Badge](https://api.codacy.com/project/badge/grade/16f6786edb554f1ea7462353808011d6)](https://www.codacy.com/app/takus/fluent-plugin-ec2-metadata)

[Fluentd](http://fluentd.org) plugin to add Amazon EC2 metadata fields to a event record

## Requirements

| fluent-plugin-ec2-metadata | fluentd    | ruby   |
|--------------------|------------|--------|
|  >= 0.1.0            | v0.14.x | >= 2.1 |
|  0.0.15 <=            | v0.12.x | >= 1.9 |

## Installation
Use RubyGems:

    gem install fluent-plugin-ec2-metadata

## Configuration

Example:

    <match foo.**>
      @type ec2_metadata

      aws_key_id  YOUR_AWS_KEY_ID
      aws_sec_key YOUR_AWS_SECRET/KEY

      metadata_refresh_seconds 300 # Optional, default 300 seconds
      imdsv2 true                  # Optional, default false

      output_tag ${instance_id}.${tag}
      <record>
        hostname      ${tagset_name}
        instance_id   ${instance_id}
        instance_type ${instance_type}
        az            ${availability_zone}
        private_ip    ${private_ip}
        vpc_id        ${vpc_id}
        ami_id        ${image_id}
        account_id    ${account_id}
      </record>
    </match>

Assume following input is coming:

```
foo.bar {"message":"hello ec2!"}
```

then output becomes as below (indented):

```
i-28b5ee77.foo.bar {
  "hostname"      : "web0001",
  "instance_id"   : "i-28b5ee77",
  "instance_type" : "m1.large",
  "az"            : "us-west-1b",
  "private_ip     : "10.21.34.200",
  "vpc_id"        : "vpc-25dab194",
  "account_id"    : "123456789",
  "image_id"      : "ami-123456",
  "message"       : "hello ec2!"
}
```

Or you can use filter version:

    <filter foo.**>
      @type ec2_metadata

      aws_key_id  YOUR_AWS_KEY_ID      
      aws_sec_key YOUR_AWS_SECRET/KEY

      metadata_refresh_seconds 300 # Optional, default 300 seconds
      imdsv2 true                  # Optional, default false

      <record>
        hostname      ${tagset_name}
        instance_id   ${instance_id}
        instance_type ${instance_type}
        private_ip    ${private_ip}
        az            ${availability_zone}
        vpc_id        ${vpc_id}
        ami_id        ${image_id}
        account_id    ${account_id}
      </record>
    </filter>

### Placeholders

The following placeholders are always available:

* ${tag} input tag
* ${tag_parts} input tag splitted by '.'. you can use it like `${tag_parts[0]}` or `${tag_parts[-1]}`
* ${instance_id} instance id
* ${instance_type} instance type
* ${availability_zone} availability zone
* ${region} region
* ${private_ip} private ip
* ${mac} MAC address
* ${vpc_id} vpc id
* ${subnet_id} subnet id
* ${account_id} account id
* ${image_id} ami image id

The followings are available when you define `aws_key_id` and `aws_sec_key`(or define IAM Policy):

* ${tagset_xxx} EC2 tag (e.g. tagset_name is replaced by the value of Key = Name)

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

Refer to the [AWS documentation](http://docs.aws.amazon.com/IAM/latest/UserGuide/ExampleIAMPolicies.html) for example policies.
Using [IAM roles](http://docs.aws.amazon.com/IAM/latest/UserGuide/WorkingWithRoles.html) with a properly configured IAM policy are preferred over embedding access keys on EC2 instances.

## Contributing

1. Fork it
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request
