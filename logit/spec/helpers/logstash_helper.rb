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
    @logstash_stdin, @logstash_stdout, @logstash_stderr, @logstash_process =
      Open3.popen3 "logstash", "--log.level", "error", "-e", prepended_config
  end

  def wait_to_start
    return close unless @logstash_process.alive?
    Timeout::timeout(@start_timeout_secs, nil, "logstash did not start within #{@start_timeout_secs} seconds") do
      # Write a line to the input and wait for the first chunk of output
      @logstash_stdin.write "ping\n"
      output_messages.first
      true
    end
  end

  def parse_line(input)
    return close unless @logstash_process.alive?
    Timeout::timeout(@message_timeout_secs, nil, "logstash didn't parse the message within #{@message_timeout_secs} seconds") do
      @logstash_stdin.write input + "\n"
      output_messages.first
    end
  end

  def close
    @logstash_stdin.close
    status = @logstash_process.value

    puts "logstash stdout:\n#{@logstash_stdout.read}"
    puts "logstash stderr:\n#{@logstash_stderr.read}"

    status
  end

  private

  def lines
    @logstash_stdout.each_line
  end

  def output_messages
    @logstash_stdout.slice_after(/^}$/).lazy.map { |chunk| chunk.join("") }
  end
end

