require 'airbrake'
require 'rails'

require 'airbrake/rails/middleware'

module Airbrake
  class Railtie < ::Rails::Railtie
    rake_tasks do
      require 'airbrake/rake_handler'
      require 'airbrake/rails3_tasks'
    end

    initializer "airbrake.middleware" do |app|
      # Since Rails 3.2 the ActionDispatch::DebugExceptions middleware is
      # responsible for logging exceptions and showing a debugging page in
      # case the request is local. We want to insert our middleware after
      # DebugExceptions, so we don't notify Airbrake about local requests.

      if ::Rails.version.start_with?('5.')
        # Avoid the warning about deprecated strings.
        # Insert after DebugExceptions, since ConnectionManagement doesn't
        # exist in Rails 5 anymore.
        app.config.middleware.insert_after(
          ActionDispatch::DebugExceptions,
          Airbrake::Rails::Middleware
        )
      elsif defined?(ActiveRecord)
        # Insert after ConnectionManagement to avoid DB connection leakage:
        # https://github.com/airbrake/airbrake/pull/568
        app.config.middleware.insert_after(
          ActiveRecord::ConnectionAdapters::ConnectionManagement,
          'Airbrake::Rails::Middleware'
        )
      else
        # Insert after DebugExceptions for apps without ActiveRecord.
        app.config.middleware.insert_after(
          ActionDispatch::DebugExceptions,
          'Airbrake::Rails::Middleware'
        )
      end
    end

    config.after_initialize do
      Airbrake.configure(true) do |config|
        config.logger           ||= config.async? ? ::Logger.new(STDERR) : ::Rails.logger
        config.environment_name ||= ::Rails.env
        config.project_root     ||= ::Rails.root
        config.framework        = "Rails: #{::Rails::VERSION::STRING}"
      end

      ActiveSupport.on_load(:action_controller) do
        # Lazily load action_controller methods
        #
        require 'airbrake/rails/controller_methods'

        include Airbrake::Rails::ControllerMethods
      end
    end
  end
end
