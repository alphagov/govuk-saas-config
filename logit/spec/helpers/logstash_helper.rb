require 'open3'
require 'timeout'

class Logstash

  @start_timeout_secs = 60
  @message_timeout_secs = 5

  def initialize(config)
    prepended_config = <<~CONFIG
    input { stdin { } }
    output { stdout { } }
    #{config}
    CONFIG
    puts ENV['PATH']
    puts prepended_config
    @logstash_stdin, @logstash_stdout, @logstash_stderr, @logstash_process =
      Open3.popen3 "/usr/share/logstash/bin/logstash", "--log.level", "error", "-e", prepended_config
  end

  def wait_to_start
    Timeout::timeout(@start_timeout_secs, nil, "logstash did not start within #{@start_timeout_secs} seconds") do
      raise "logstash did not start" unless @logstash_process.alive?
      raise "logstash closed STDIN" if @logstash_stdin.closed?

      # Write a line to the input and wait for the first chunk of output
      @logstash_stdin.write "ping\n"
      output_messages.first
      self
    end
  end

  def parse_line(input)
    Timeout::timeout(@message_timeout_secs, nil, "logstash didn't parse the message within #{@message_timeout_secs} seconds") do
      raise "logstash is not running" unless @logstash_process.alive?
      raise "logstash closed STDIN" if @logstash_stdin.closed?

      @logstash_stdin.write input + "\n"
      output_messages.first
    end
  end

  def close
    @logstash_stdin.close
    @logstash_process.value
  end

  private

  def lines
    @logstash_stdout.each_line
  end

  def output_messages
    @logstash_stdout.slice_after(/^}$/).lazy.map { |chunk| chunk.join("") }
  end
end

