require 'helper'
require 'fluent/plugin/out_ec2_metadata'

require 'webmock/test_unit'
WebMock.disable_net_connect!

class EC2MetadataOutputTest < Test::Unit::TestCase

  CONFIG = %[
    output_tag ${instance_id}.${tag}
    aws_key_id aws_key
    aws_sec_key aws_sec
    <record>
      name ${tagset_name}
      instance_id ${instance_id}
      az ${availability_zone}
    </record>
  ]

  def setup
    Fluent::Test.setup
    @time = Fluent::Engine.now
  end

  def create_driver(conf=CONFIG, tag='test')
    Fluent::Test::OutputTestDriver.new(Fluent::EC2MetadataOutput, tag).configure(conf)
  end

  test 'configure-vpc' do
    VCR.use_cassette('ec2-vpc') do
      c = %[
        output_tag ${instance_id}.${tag}
        aws_key_id aws_key
        aws_sec_key aws_sec
        <record>
          name ${tagset_name}
        </record>
      ]
      d = create_driver(conf=c)

      assert_equal("${instance_id}.${tag}", d.instance.output_tag)
      assert_equal("aws_key", d.instance.aws_key_id)
      assert_equal("aws_sec", d.instance.aws_sec_key)

      assert_equal("ami-123456", d.instance.ec2_metadata['image_id'])
      assert_equal("123456789", d.instance.ec2_metadata['account_id'])
      assert_equal("10.21.34.200", d.instance.ec2_metadata['private_ip'])

      assert_equal("i-0c0c0000", d.instance.ec2_metadata['instance_id'])
      assert_equal("m3.large", d.instance.ec2_metadata['instance_type'])
      assert_equal("ap-northeast-1", d.instance.ec2_metadata['region'])
      assert_equal("ap-northeast-1b", d.instance.ec2_metadata['availability_zone'])
      assert_equal("00:A0:00:0A:AA:00", d.instance.ec2_metadata['mac'])
      assert_equal("vpc-00000000", d.instance.ec2_metadata['vpc_id'])
      assert_equal("subnet-00000000", d.instance.ec2_metadata['subnet_id'])

      assert_equal("instance-name", d.instance.ec2_metadata['tagset_name'])
    end
  end

  test 'configure-classic' do
    VCR.use_cassette('ec2-classic') do
      c = %[
        output_tag test
        <record>
          instance_id ${instance_id}
        </record>
      ]
      d = create_driver(conf=c)

      assert_equal("test", d.instance.output_tag)
      assert_equal(nil, d.instance.aws_key_id)
      assert_equal(nil, d.instance.aws_sec_key)

      assert_equal("00:00:0A:AA:0A:0A", d.instance.ec2_metadata['mac'])
      assert_equal(nil, d.instance.ec2_metadata['vpc_id'])
      assert_equal(nil, d.instance.ec2_metadata['subnet_id'])
    end
  end

  test 'emit' do
    VCR.use_cassette('ec2-vpc') do
      d = create_driver

      d.run do
        d.emit("a" => 1)
        d.emit("a" => 2)
      end

      # tag
      assert_equal "i-0c0c0000.test", d.emits[0][0]
      assert_equal "i-0c0c0000.test", d.emits[1][0]

      # record
      mapped = { 'instance_id' => 'i-0c0c0000', 'az' => 'ap-northeast-1b', 'name' => 'instance-name' }
      assert_equal [
        {"a" => 1}.merge(mapped),
        {"a" => 2}.merge(mapped),
      ], d.records
    end
  end

end
