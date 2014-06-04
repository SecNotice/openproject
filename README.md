# OpenProject AuthPlugins Plugin

Adds support for easy integration of OmniAuth strategy providers as a means to authenticate users in OpenProject.

## Dependencies

This plugin depends on the OpenProject Plugins Plugin, so insert it into your `Gemfile.plugins`:

    gem "openproject-plugins", :git => "git@github.com:opf/openproject-plugins.git", :branch => "dev"

## Usage

You can use this plugin to make an authentication plugin out of an ordinary OpenProject plugin.
The first step is to generate a new plugin using the Plugins plugin.
Once you have done that it only takes a few additions to make it an authentication plugin.
Find your Engine class in `engine.rb`, let it extend `OpenProject::Plugin::AuthPlugin` and register the providers you want to use.

Here's an example of that might look:

    module OpenProject::SomeAuthPlugin
      class Engine < ::Rails::Engine
        engine_name :openproject_some_auth_plugin

        include OpenProject::Plugins::ActsAsOpEngine
        extend OpenProject::Plugins::AuthPlugin

        register 'openproject-some_auth_plugin',
                 author_url: 'http://my.site',
                 requires_openproject: '>= 3.1.0pre1'

        assets %w(
          some_auth_plugin/some_provider.png
        )

        register_auth_providers do
          strategy :some_strategy do
            [
              {
                name: "some_provider",
                host: "foo.bar.baz",
                port: 999,
                #, ... more provider options
                icon: 'some_auth_plugin/some_provider.png'
              },
              {
                name: "another_provider",
                host: "foobar.biz",
                port: "692",
                #, ... more provider options
              }
            ]
          end

          strategy :another_strategy do
            [{name: "yet_another_provider"}]
          end
        end
      end
    end

Register each OmniAuth strategy by calling `strategy` with the strategy's name and returning the options for the providers using that strategy in the passed block.

As you can see in the first registered provider you can also give a new option called 'icon'.
Using this option you can define which icon is to be rendered for the given provider.
In the example our own plugin provides the icon. In the plugin's directory it has to be placed under `app/assets/images/some_auth_plugin/some_provider.png`.
