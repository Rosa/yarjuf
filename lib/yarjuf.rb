require 'time'
require 'builder'
require 'rspec/core/formatters/base_formatter'

class JUnit < RSpec::Core::Formatters::BaseFormatter
  def initialize(output)
    super output
    @test_suite_results = {}
  end

  def example_passed(example)
    add_to_test_suite_results(example)
  end

  def example_failed(example)
    add_to_test_suite_results(example)
  end

  def example_pending(example)
    add_to_test_suite_results(example)
  end

  def add_to_test_suite_results(example)
    suite_name = root_group_name_for(example)
    @test_suite_results[suite_name] = [] unless @test_suite_results.keys.include?(suite_name)
    @test_suite_results[suite_name] << example
  end

  def root_group_name_for(example)
    group_hierarchy_for(example).first[:description]
  end

  def group_hierarchy_for(example)
    group_hierarchy = []
    current_example_group = example.metadata[:example_group]
    until current_example_group.nil? do
      group_hierarchy.unshift current_example_group
      current_example_group = current_example_group[:example_group]
    end
    group_hierarchy
  end

  def failure_details_for(example)
    exception = example.metadata[:execution_result][:exception]
    exception.nil? ? "" : "#{exception.message}\n#{format_backtrace(exception.backtrace, example).join("\n")}"
  end

  def fail_count_for_suite(suite)
    suite.select {|example| example.metadata[:execution_result][:status] == "failed"}.size
  end

  def skipped_count_for_suite(suite)
    suite.select {|example| example.metadata[:execution_result][:status] == "pending"}.size
  end

  def dump_summary(duration, example_count, failure_count, pending_count)
    builder = Builder::XmlMarkup.new :indent => 2
    builder.instruct! :xml, :version => "1.0", :encoding => "UTF-8"
    builder.testsuites :errors => 0, :failures => failure_count, :skipped => pending_count, :tests => example_count, :time => duration, :timestamp => Time.now.iso8601 do
      @test_suite_results.each do |suite_name, tests|
        build_test_suite builder, suite_name, tests
      end
    end
    output.puts builder.target!
  end

  def build_test_suite(xml_builder, suite_name, tests)
    xml_builder.testsuite :name => suite_name, :tests => tests.size, :errors => 0, :failures => fail_count_for_suite(tests), :skipped => skipped_count_for_suite(tests) do
      xml_builder.properties
      tests.each do |test|
        build_test xml_builder, test
      end
    end
  end

  def build_test(xml_builder, test)
    xml_builder.testcase :name => test.metadata[:full_description], :time => test.metadata[:execution_result][:run_time] do
      case test.metadata[:execution_result][:status]
      when "pending" then xml_builder.skipped
      when "failed"
        xml_builder.failure :message => "failed #{test.metadata[:full_description]}", :type => "failed" do
          xml_builder.cdata! failure_details_for test
        end
      end
    end
  end
end

