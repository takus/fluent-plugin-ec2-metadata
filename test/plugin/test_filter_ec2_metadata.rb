require 'helper'
require 'fluent/test/driver/filter'
require 'fluent/plugin/filter_ec2_metadata'

require 'webmock/test_unit'
WebMock.disable_net_connect!

class EC2MetadataFilterTest < Test::Unit::TestCase

  CONFIG = %[
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

  def create_driver(conf=CONFIG)
    Fluent::Test::Driver::Filter.new(Fluent::Plugin::EC2MetadataFilter).configure(conf)
  end

  test 'configure-vpc' do
    VCR.use_cassette('ec2-vpc') do
      c = %[
        aws_key_id aws_key
        aws_sec_key aws_sec
        <record>
          name ${tagset_name}
        </record>
      ]
      d = create_driver(conf=c)

      assert_equal("aws_key", d.instance.aws_key_id)
      assert_equal("aws_sec", d.instance.aws_sec_key)

      assert_equal("ami-123456", d.instance.ec2_metadata['image_id'])
      assert_equal("123456789", d.instance.ec2_metadata['account_id'])

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

  test 'configure-vpc-with-imdsv2' do
    VCR.use_cassette('ec2-vpc-with-imdsv2', :allow_playback_repeats => true) do
      c = %[
        aws_key_id aws_key
        aws_sec_key aws_sec
        imdsv2 true
        <record>
          name ${tagset_name}
        </record>
      ]
      d = create_driver(conf=c)

      assert_equal("aws_key", d.instance.aws_key_id)
      assert_equal("aws_sec", d.instance.aws_sec_key)

      assert_equal("ami-123456", d.instance.ec2_metadata['image_id'])
      assert_equal("123456789", d.instance.ec2_metadata['account_id'])

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
        <record>
          instance_id ${instance_id}
        </record>
      ]
      d = create_driver(conf=c)

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

      d.run(default_tag: 'test') do
        d.feed("a" => 1)
        d.feed("a" => 2)
      end

      # record
      mapped = {
        'instance_id' => 'i-0c0c0000',
        'az' => 'ap-northeast-1b',
        'name' => 'instance-name',
      }
      assert_equal [
        {"a" => 1}.merge(mapped),
        {"a" => 2}.merge(mapped),
      ], d.filtered.map{|e| e.last}
    end
  end
end
