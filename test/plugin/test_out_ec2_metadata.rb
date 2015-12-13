require 'helper'

require 'webmock/test_unit'
WebMock.disable_net_connect!

class EC2MetadataOutputTest < Test::Unit::TestCase
  def setup
    Fluent::Test.setup
  end

  CONFIG = %[
    output_tag ${instance_id}.${tag}
    <record>
      instance_id ${instance_id}
      az          ${availability_zone}
    </record>
  ]

  def create_driver(conf = CONFIG, tag='test')
    Fluent::Test::OutputTestDriver.new(Fluent::EC2MetadataOutput, tag).configure(conf)
  end

  def test_emit
	VCR.use_cassette('ec2') do
      d = create_driver(CONFIG, 'foo.bar')

      d.run do
        d.emit("a" => 1)
        d.emit("a" => 2)
      end

      # tag
      assert_equal "i-0c0c0000.foo.bar", d.emits[0][0]
      assert_equal "i-0c0c0000.foo.bar", d.emits[1][0]

      # record
      mapped = { 'instance_id' => 'i-0c0c0000', 'az' => 'ap-northeast-1b' }
      assert_equal [
        {"a" => 1}.merge(mapped),
        {"a" => 2}.merge(mapped),
      ], d.records
    end
  end
end
