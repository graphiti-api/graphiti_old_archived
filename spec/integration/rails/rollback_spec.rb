if ENV["APPRAISAL_INITIALIZED"]
  RSpec.describe 'rollback hooks', type: :controller do
    class Callbacks
      class << self
        attr_accessor :rollbacks, :commits
      end

      def self.add_rollback(object)
        self.rollbacks << object
      end

      def self.add_commit(object)
        self.commits << object
      end
    end

    before do
      Callbacks.rollbacks = []
      Callbacks.commits = []
      $raise_on_before_commit = { }
    end

    before do
      allow(controller.request).to receive(:env).and_return(Rack::MockRequest.env_for(path))
    end

    let(:path) { '/integration_hooks/employees' }

    module IntegrationHooks
      class ApplicationResource < Graphiti::Resource
        self.adapter = Graphiti::Adapters::ActiveRecord
        before_commit do |record|
          Callbacks.add_commit(record)

          if $raise_on_before_commit[record.class.name]
            raise 'rollitback'
          end

          record
        end
      end

      class DepartmentResource < ApplicationResource
        self.model = ::Department

        on_rollback do |record|
          Callbacks.add_rollback(record)
        end
      end

      class PositionResource < ApplicationResource
        self.model = ::Position

        attribute :employee_id, :integer, only: [:writable]

        on_rollback do |record|
          Callbacks.add_rollback(record)
        end

        belongs_to :department
      end

      class EmployeeResource < ApplicationResource
        self.model = ::Employee

        attribute :first_name, :string

        on_rollback only: [:create] do |record|
          Callbacks.add_rollback(record)
        end

        has_many :positions
      end
    end

    controller(ApplicationController) do
      def create
        employee = IntegrationHooks::EmployeeResource.build(params)

        if employee.save
          render jsonapi: employee
        else
          raise 'whoops'
        end
      end

      private

      def params
        @params ||= begin
          hash = super.to_unsafe_h.with_indifferent_access
          hash = hash[:params] if hash.has_key?(:params)
          hash
        end
      end
    end

    before do
      @request.headers['Accept'] = Mime[:json]
      @request.headers['Content-Type'] = Mime[:json].to_s

      routes.draw {
        post "create" => "anonymous#create"
        put "update" => "anonymous#update"
        delete "destroy" => "anonymous#destroy"
      }
    end

    def json
      JSON.parse(response.body)
    end

    context 'on_rollback' do
      context 'when creating a single resource' do
        let(:payload) do
          {
            data: {
              type: 'employees',
              attributes: { first_name: 'Jane' }
            }
          }
        end

        context 'when the creation is successful' do
          it "does not call rollback hook" do
            post :create, params: payload

            expect(Callbacks.rollbacks).to eq []
          end
        end

        context 'when the resource raises an error in before_commit' do
          before do
            $raise_on_before_commit = { 'Employee' => true }
          end

          it "does not call rollback hook" do
            expect {
              post :create, params: payload
            }.to raise_error('rollitback')

            expect(Callbacks.rollbacks).to eq []
          end
        end
      end

      context 'creating nested resources' do
        let(:payload) do
          {
            data: {
              type: 'employees',
              attributes: { first_name: 'joe' },
              relationships: {
                positions: {
                  data: [
                    { :'temp-id' => 'a', type: 'positions', method: 'create' }
                  ]
                }
              }
            },
            included: [
              {
                type: 'positions',
                :'temp-id' => 'a',
                relationships: {
                  department: {
                    data: {
                      :'temp-id' => 'b', type: 'departments', method: 'create'
                    }
                  }
                }
              },
              {
                type: 'departments',
                :'temp-id' => 'b'
              }
            ]
          }
        end

        context 'when creation is successful' do
          it 'does not call any rollback hooks' do
            post :create, params: payload

            expect(Callbacks.rollbacks).to eq []
          end
        end

        context 'when one of the resources throws an error in a before_commit hook' do
          before do
            $raise_on_before_commit = { 'Department' => true }
          end

          it 'runs rollback hook for any previously commited resources in reverse order' do
            expect {
              post :create, params: payload
            }.to raise_error('rollitback')

            expect(Callbacks.rollbacks).to eq [Callbacks.commits[1], Callbacks.commits[0]]
          end
        end
      end
    end
  end
end
