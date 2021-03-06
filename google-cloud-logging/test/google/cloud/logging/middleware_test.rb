# Copyright 2016 Google Inc. All rights reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.


require "helper"

describe Google::Cloud::Logging::Middleware, :mock_logging do
  let(:app_exception_msg) { "A serious error from application" }
  let(:service_name) { "My microservice" }
  let(:service_version) { "Version testing" }
  let(:trace_id) { "a-very-unique-identifier" }
  let(:trace_context) { "#{trace_id}/a-span-id/options" }
  let(:rack_env) {{
    "HTTP_X_CLOUD_TRACE_CONTEXT" => trace_context
  }}
  let(:app_exception) { StandardError.new(app_exception_msg) }
  let(:rack_app) {
    app = OpenStruct.new
    def app.call(_) end
    app
  }
  let(:log_name) { "web_app_log" }
  let(:resource) do
    Google::Cloud::Logging::Resource.new.tap do |r|
      r.type = "gce_instance"
      r.labels["zone"] = "global"
      r.labels["instance_id"] = "abc123"
    end
  end
  let(:labels) { { "env" => "production" } }
  let(:logger) { Google::Cloud::Logging::Logger.new logging, log_name, resource, labels }
  let(:middleware) {
    Google::Cloud::Logging::Middleware.new rack_app, logger: logger
  }

  describe "#call" do
    it "sets env[\"rack.logger\"] to the given logger" do
      stubbed_call = ->(env) {
        env["rack.logger"].must_equal logger
      }
      rack_app.stub :call, stubbed_call do
        middleware.call rack_env
      end
    end

    it "calls logger.add_trace_id to track trace_id" do
      stubbed_add_trace_id = ->(this_trace_id) {
        this_trace_id.must_equal trace_id
      }
      logger.stub :add_trace_id, stubbed_add_trace_id do
        middleware.call rack_env
      end
    end

    it "calls logger.delete_trace_id when exiting even app.call fails" do
      method_called = false
      stubbed_delete_trace_id = ->() {
        method_called = true
      }
      stubbed_call = ->(_) { raise "die" }

      logger.stub :delete_trace_id, stubbed_delete_trace_id do
        rack_app.stub :call, stubbed_call do
          assert_raises StandardError do
            middleware.call rack_env
          end
          method_called.must_equal true
        end
      end
    end
  end

  describe "#extract_trace_id" do
    it "extracts trace_id from trace_context" do
      middleware.extract_trace_id(rack_env).must_equal trace_id
    end
  end

  describe ".build_monitored_resource" do
    let(:custom_type) { "custom-monitored-resource-type" }
    let(:custom_labels) { {label_one: 1, label_two: 2} }
    let(:default_rc) { "Default-monitored-resource" }

    it "returns resource of right type if given parameters" do
      Google::Cloud::Logging::Middleware.stub :default_monitored_resource, default_rc do
        rc = Google::Cloud::Logging::Middleware.build_monitored_resource custom_type, custom_labels
        rc.type.must_equal custom_type
        rc.labels.must_equal custom_labels
      end
    end

    it "returns default monitored resource if only given type" do
      Google::Cloud::Logging::Middleware.stub :default_monitored_resource, default_rc do
        rc = Google::Cloud::Logging::Middleware.build_monitored_resource custom_type
        rc.must_equal default_rc
      end
    end

    it "returns default monitored resource if only given labels" do
      Google::Cloud::Logging::Middleware.stub :default_monitored_resource, default_rc do
        rc = Google::Cloud::Logging::Middleware.build_monitored_resource nil, custom_labels
        rc.must_equal default_rc
      end
    end
  end

  describe ".default_monitored_resource" do
    it "returns resource of type gae_app if gae? is true" do
      Google::Cloud::Core::Environment.stub :gae?, true do
        Google::Cloud::Core::Environment.stub :gke?, false do
          Google::Cloud::Core::Environment.stub :gce?, false do
            rc = Google::Cloud::Logging::Middleware.build_monitored_resource
            rc.type.must_equal "gae_app"
          end
        end
      end
    end

    it "returns resource of type container if gke? is true" do
      Google::Cloud::Core::Environment.stub :gae?, false do
        Google::Cloud::Core::Environment.stub :gke?, true do
          Google::Cloud::Core::Environment.stub :gce?, false do
            rc = Google::Cloud::Logging::Middleware.build_monitored_resource
            rc.type.must_equal "container"
          end
        end
      end
    end

    it "returns resource of type gce_instance if gce? is true" do
      Google::Cloud::Core::Environment.stub :gae?, false do
        Google::Cloud::Core::Environment.stub :gke?, false do
          Google::Cloud::Core::Environment.stub :gce?, true do
            rc = Google::Cloud::Logging::Middleware.build_monitored_resource
            rc.type.must_equal "gce_instance"
          end
        end
      end
    end

    it "returns resource of type global if not on GCP" do
      Google::Cloud::Core::Environment.stub :gae?, false do
        Google::Cloud::Core::Environment.stub :gke?, false do
          Google::Cloud::Core::Environment.stub :gce?, false do
            rc = Google::Cloud::Logging::Middleware.build_monitored_resource
            rc.type.must_equal "global"
          end
        end
      end
    end
  end
end
