require_relative 'spec_helper'
require_relative 'helpers/logstash_helper'

RSpec.describe "aws_logstash.conf" do

  logstash = nil

  before :all do
    config = File.read "#{__dir__}/../aws_logstash.conf"
    logstash = Logstash.new config
    logstash.wait_to_start
  end

  after :all do
    logstash.close unless logstash.nil?
  end

  it "should pass through unformatted log messages" do
    output = logstash.parse_line "hello world!"
    expect(output).to match(/"message"\s*=>\s*"hello world!"/)
  end

  it "should parse json_log: true messages as json" do
    input = '{"json_log": true, "some-field": "some-value"}'
    output = logstash.parse_line input
    expect(output).to match(/"json_log"\s*=>\s*true/)
    expect(output).to match(/"some-field"\s*=>\s*"some-value"/)
    expect(output).to include(input.gsub('"', '\"'))
  end
end
