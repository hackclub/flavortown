require 'swagger_helper'

RSpec.describe 'API V1 OpenAPI', openapi_spec: 'openapi.yml', type: :request do
  def self.documented_ref_response(code, description, ref)
    response code, description do
      metadata[:response] = { code: code, '$ref' => ref }
      run_test!
    end
  end

  path '/projects' do
    get 'List projects' do
      tags 'Projects'
      description 'Fetch a list of projects. Ratelimit: 5 reqs/min, 20 reqs/min if searching.'
      operationId 'listProjects'
      produces 'application/json'

      parameter name: :page,
                in: :query,
                required: false,
                schema: { type: :integer },
                description: 'Page number for pagination'

      parameter name: :query,
                in: :query,
                required: false,
                schema: { type: :string },
                description: 'Search projects by title or description'

      response '200', 'A paginated list of projects' do
        schema type: :object,
               properties: {
                 projects: {
                   type: :array,
                   items: { '$ref' => '#/components/schemas/Project' }
                 },
                 pagination: { '$ref' => '#/components/schemas/Pagination' }
               }
        run_test!
      end

      documented_ref_response '401', 'Missing or invalid API key', '#/components/responses/Unauthorized'
    end

    post 'Create a project' do
      tags 'Projects'
      description 'Create a new project.'
      operationId 'createProject'
      consumes 'application/x-www-form-urlencoded'
      produces 'application/json'

      parameter name: :project,
                in: :body,
                required: true,
                schema: {
                  type: :object,
                  required: %w[title description],
                  properties: {
                    title: { type: :string, description: 'Project title' },
                    description: { type: :string, description: 'Project description' },
                    repo_url: { type: :string, description: 'URL to the source code repository' },
                    demo_url: { type: :string, description: 'URL to the live demo' },
                    readme_url: { type: :string, description: 'URL to the README' },
                    ai_declaration: { type: :string, description: 'Declaration of AI tools used in this project' }
                  }
                }

      response '201', 'Project created' do
        schema '$ref' => '#/components/schemas/Project'
        run_test!
      end

      documented_ref_response '401', 'Missing or invalid API key', '#/components/responses/Unauthorized'

      documented_ref_response '422', 'Validation failed', '#/components/responses/UnprocessableEntity'
    end
  end

  path '/projects/{id}' do
    parameter name: :id, in: :path, required: true, schema: { type: :integer }

    get 'Get a project' do
      tags 'Projects'
      description 'Fetch a specific project by ID. Ratelimit: 30 reqs/min.'
      operationId 'getProject'
      produces 'application/json'

      response '200', 'A single project' do
        schema '$ref' => '#/components/schemas/Project'
        run_test!
      end

      documented_ref_response '401', 'Missing or invalid API key', '#/components/responses/Unauthorized'

      documented_ref_response '404', 'Resource not found', '#/components/responses/NotFound'
    end

    patch 'Update a project' do
      tags 'Projects'
      description 'Update an existing project.'
      operationId 'updateProject'
      consumes 'application/x-www-form-urlencoded'
      produces 'application/json'

      parameter name: :project,
                in: :body,
                required: true,
                schema: {
                  type: :object,
                  properties: {
                    title: { type: :string, description: 'Project title' },
                    description: { type: :string, description: 'Project description' },
                    repo_url: { type: :string, description: 'URL to the source code repository' },
                    demo_url: { type: :string, description: 'URL to the live demo' },
                    readme_url: { type: :string, description: 'URL to the README' },
                    ai_declaration: { type: :string, description: 'Declaration of AI tools used in this project' }
                  }
                }

      response '200', 'Project updated' do
        schema '$ref' => '#/components/schemas/Project'
        run_test!
      end

      documented_ref_response '401', 'Missing or invalid API key', '#/components/responses/Unauthorized'

      documented_ref_response '403', 'Permission denied', '#/components/responses/Forbidden'

      documented_ref_response '404', 'Resource not found', '#/components/responses/NotFound'

      documented_ref_response '422', 'Validation failed', '#/components/responses/UnprocessableEntity'
    end
  end

  path '/projects/{project_id}/devlogs' do
    get 'List project devlogs' do
      tags 'Projects'
      description 'Fetch all devlogs for a specific project.'
      operationId 'listProjectDevlogs'
      produces 'application/json'

      parameter name: :project_id,
                in: :path,
                required: true,
                schema: { type: :integer }

      response '200', 'A paginated list of devlogs for the project' do
        schema type: :object,
               properties: {
                 devlogs: {
                   type: :array,
                   items: { '$ref' => '#/components/schemas/Devlog' }
                 },
                 pagination: { '$ref' => '#/components/schemas/Pagination' }
               }
        run_test!
      end

      documented_ref_response '401', 'Missing or invalid API key', '#/components/responses/Unauthorized'

      documented_ref_response '404', 'Resource not found', '#/components/responses/NotFound'
    end
  end

  path '/devlogs' do
    get 'List devlogs' do
      tags 'Devlogs'
      description 'Fetch all devlogs across all projects.'
      operationId 'listDevlogs'
      produces 'application/json'

      parameter name: :page,
                in: :query,
                required: false,
                schema: { type: :integer },
                description: 'Page number for pagination'

      response '200', 'A paginated list of devlogs' do
        schema type: :object,
               properties: {
                 devlogs: {
                   type: :array,
                   items: { '$ref' => '#/components/schemas/Devlog' }
                 },
                 pagination: { '$ref' => '#/components/schemas/Pagination' }
               }
        run_test!
      end

      documented_ref_response '401', 'Missing or invalid API key', '#/components/responses/Unauthorized'
    end
  end

  path '/devlogs/{id}' do
    get 'Get a devlog' do
      tags 'Devlogs'
      description 'Fetch a devlog by ID.'
      operationId 'getDevlog'
      produces 'application/json'

      parameter name: :id,
                in: :path,
                required: true,
                schema: { type: :integer }

      response '200', 'A single devlog' do
        schema '$ref' => '#/components/schemas/Devlog'
        run_test!
      end

      documented_ref_response '401', 'Missing or invalid API key', '#/components/responses/Unauthorized'

      documented_ref_response '404', 'Resource not found', '#/components/responses/NotFound'
    end
  end

  path '/store' do
    get 'List store items' do
      tags 'Store'
      description 'Fetch a list of store items. Ratelimit: 5 reqs/min.'
      operationId 'listStoreItems'
      produces 'application/json'

      response '200', 'A list of store items' do
        schema type: :array,
               items: { '$ref' => '#/components/schemas/StoreItem' }
        run_test!
      end

      documented_ref_response '401', 'Missing or invalid API key', '#/components/responses/Unauthorized'
    end
  end

  path '/store/{id}' do
    get 'Get a store item' do
      tags 'Store'
      description 'Fetch a specific store item by ID. Ratelimit: 30 reqs/min.'
      operationId 'getStoreItem'
      produces 'application/json'

      parameter name: :id,
                in: :path,
                required: true,
                schema: { type: :integer }

      response '200', 'A single store item' do
        schema '$ref' => '#/components/schemas/StoreItem'
        run_test!
      end

      documented_ref_response '401', 'Missing or invalid API key', '#/components/responses/Unauthorized'

      documented_ref_response '404', 'Resource not found', '#/components/responses/NotFound'
    end
  end

  path '/users' do
    get 'List users' do
      tags 'Users'
      description 'Fetch a list of users. Ratelimit: 5 reqs/min.'
      operationId 'listUsers'
      produces 'application/json'

      parameter name: :page,
                in: :query,
                required: false,
                schema: { type: :integer },
                description: 'Page number for pagination'

      parameter name: :query,
                in: :query,
                required: false,
                schema: { type: :string },
                description: 'Search users by display name or slack ID'

      response '200', 'A paginated list of users' do
        schema type: :object,
               properties: {
                 users: {
                   type: :array,
                   items: { '$ref' => '#/components/schemas/User' }
                 },
                 pagination: { '$ref' => '#/components/schemas/Pagination' }
               }
        run_test!
      end

      documented_ref_response '401', 'Missing or invalid API key', '#/components/responses/Unauthorized'
    end
  end

  path '/users/{id}' do
    get 'Get a user' do
      tags 'Users'
      description 'Fetch a specific user by ID. Use "me" as the ID to fetch the authenticated user.'
      operationId 'getUser'
      produces 'application/json'

      parameter name: :id,
                in: :path,
                required: true,
                schema: { type: :string },
                description: 'User ID or "me" for the authenticated user'

      response '200', 'A single user with additional stats' do
        schema '$ref' => '#/components/schemas/UserDetail'
        run_test!
      end

      documented_ref_response '401', 'Missing or invalid API key', '#/components/responses/Unauthorized'

      documented_ref_response '404', 'Resource not found', '#/components/responses/NotFound'
    end
  end
end
