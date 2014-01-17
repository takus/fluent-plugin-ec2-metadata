require 'helper'

class EC2MetadataOutputTest < Test::Unit::TestCase
  def setup
    Fluent::Test.setup
  end

  CONFIG = %[
    output_tag ${instance_id}.${tag}
    <record>
      instance_id ${instance_id}
    </record>
  ]

  def create_driver(conf = CONFIG, tag='test')
    Fluent::Test::OutputTestDriver.new(Fluent::EC2MetadataOutput, tag).configure(conf)
  end

  def get_instance_id
    Net::HTTP.get_response('169.254.169.254', '/latest/meta-data/instance-id').body
  end

  def test_emit
    d = create_driver(CONFIG, 'foo.bar')

    d.run do
      d.emit("a" => 1)
      d.emit("a" => 2)
    end

    instance_id = get_instance_id

    # tag
    assert_equal "#{instance_id}.foo.bar", d.emits[0][0]
    assert_equal "#{instance_id}.foo.bar", d.emits[1][0]

    # record
    mapped = { 'instance_id' => instance_id }
    assert_equal [
      {"a" => 1}.merge(mapped),
      {"a" => 2}.merge(mapped),
    ], d.records
  end
end
