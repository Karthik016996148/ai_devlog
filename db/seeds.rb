puts "Seeding AI DevLog with sample entries..."

entries_data = [
  {
    title: "Fix N+1 Query in UsersController#index",
    entry_type: :solution,
    content: <<~CONTENT
      ## Problem
      The users index page was making 100+ database queries due to N+1 queries when loading user posts.

      ## Solution
      Used `includes` to eager load associations:

      ```ruby
      # Before (N+1)
      @users = User.all
      # Each user.posts triggers a new query

      # After (eager loading)
      @users = User.includes(:posts, :comments).all
      ```

      ## Key Takeaway
      Always check the Rails logs for N+1 queries. Tools like `bullet` gem can automate detection.
    CONTENT
  },
  {
    title: "Docker container exits with error code 137",
    entry_type: :error_log,
    content: <<~CONTENT
      ## Error
      ```
      Container exited with code 137
      ERROR: Service 'web' failed to build
      ```

      ## Root Cause
      Exit code 137 means the container was killed by OOM (Out of Memory) killer.

      ## Fix
      Increased Docker Desktop memory allocation from 2GB to 4GB in Docker Desktop > Settings > Resources.

      Also added memory limits to docker-compose.yml:
      ```yaml
      services:
        web:
          deploy:
            resources:
              limits:
                memory: 2G
      ```
    CONTENT
  },
  {
    title: "PostgreSQL JSONB Column Queries",
    entry_type: :til,
    content: <<~CONTENT
      ## TIL: Querying JSONB columns in PostgreSQL with Rails

      You can query JSONB columns using the `->` and `->>` operators:

      ```ruby
      # Find users with a specific setting
      User.where("settings->>'theme' = ?", "dark")

      # Check if a key exists
      User.where("settings ? :key", key: "notifications")

      # Query nested values
      User.where("settings->'notifications'->>'email' = ?", "true")
      ```

      For indexing, use GIN indexes:
      ```ruby
      add_index :users, :settings, using: :gin
      ```

      This makes JSONB queries much faster than scanning the whole table.
    CONTENT
  },
  {
    title: "Ruby Service Object Pattern",
    entry_type: :code_snippet,
    content: <<~CONTENT
      Clean service object pattern for Rails:

      ```ruby
      class ProcessOrder
        def initialize(order, payment_method:)
          @order = order
          @payment_method = payment_method
        end

        def call
          validate_inventory!
          charge_payment!
          fulfill_order!
          send_confirmation!

          Result.new(success: true, order: @order)
        rescue PaymentError => e
          Result.new(success: false, error: e.message)
        end

        private

        def validate_inventory!
          raise InsufficientInventoryError unless @order.items.all?(&:in_stock?)
        end

        def charge_payment!
          @payment = PaymentGateway.charge(@payment_method, amount: @order.total)
        end

        def fulfill_order!
          @order.update!(status: :fulfilled, payment_id: @payment.id)
        end

        def send_confirmation!
          OrderMailer.confirmation(@order).deliver_later
        end
      end
      ```

      Usage: `ProcessOrder.new(order, payment_method: card).call`
    CONTENT
  },
  {
    title: "ActiveRecord Callbacks Execution Order",
    entry_type: :note,
    content: <<~CONTENT
      ## ActiveRecord Callback Order

      Important to remember the order callbacks fire:

      ### Creating
      1. `before_validation`
      2. `after_validation`
      3. `before_save`
      4. `before_create`
      5. `after_create`
      6. `after_save`
      7. `after_commit` / `after_create_commit`

      ### Updating
      1. `before_validation`
      2. `after_validation`
      3. `before_save`
      4. `before_update`
      5. `after_update`
      6. `after_save`
      7. `after_commit` / `after_update_commit`

      **Key gotcha**: `after_save` runs inside the transaction, but `after_commit` runs after.
      Use `after_commit` for things like sending emails or enqueuing jobs to avoid them
      running when the transaction rolls back.
    CONTENT
  },
  {
    title: "Stimulus Controller for Debounced Search",
    entry_type: :code_snippet,
    content: <<~CONTENT
      Stimulus controller with debounced input for live search:

      ```javascript
      import { Controller } from "@hotwired/stimulus"

      export default class extends Controller {
        static targets = ["input", "results"]
        static values = { url: String, delay: { type: Number, default: 300 } }

        connect() {
          this.timeout = null
        }

        search() {
          clearTimeout(this.timeout)
          this.timeout = setTimeout(() => {
            this.performSearch()
          }, this.delayValue)
        }

        async performSearch() {
          const query = this.inputTarget.value
          if (query.length < 2) return

          const response = await fetch(`${this.urlValue}?q=${encodeURIComponent(query)}`, {
            headers: { "Accept": "text/vnd.turbo-stream.html" }
          })

          if (response.ok) {
            const html = await response.text()
            Turbo.renderStreamMessage(html)
          }
        }

        disconnect() {
          clearTimeout(this.timeout)
        }
      }
      ```
    CONTENT
  },
  {
    title: "pgvector Cosine Similarity for RAG",
    entry_type: :til,
    content: <<~CONTENT
      ## TIL: Using pgvector for semantic search in Rails

      pgvector lets you store and query vector embeddings directly in PostgreSQL.
      Combined with OpenAI embeddings, this powers RAG (Retrieval-Augmented Generation).

      ### Setup
      ```ruby
      # Migration
      enable_extension "vector"
      add_column :entries, :embedding, :vector, limit: 1536

      # Model
      class Entry < ApplicationRecord
        has_neighbors :embedding
      end
      ```

      ### Querying
      ```ruby
      # Find 5 most similar entries
      entry.nearest_neighbors(:embedding, distance: "cosine").first(5)

      # Search by a query embedding
      Entry.nearest_neighbors(:embedding, query_vector, distance: "cosine").first(5)
      ```

      ### Why HNSW index?
      ```ruby
      add_index :entries, :embedding, using: :hnsw, opclass: :vector_cosine_ops
      ```
      HNSW provides approximate nearest neighbor search in sub-millisecond time,
      even with millions of vectors. Trade-off: slightly less accurate than exact search,
      but orders of magnitude faster.
    CONTENT
  },
  {
    title: "Turbo Streams from Background Jobs",
    entry_type: :solution,
    content: <<~CONTENT
      ## Problem
      Needed to broadcast real-time updates to the UI from a background job
      (e.g., showing AI processing progress).

      ## Solution
      Use `Turbo::StreamsChannel.broadcast_*` methods from any Ruby code:

      ```ruby
      class ProcessingJob < ApplicationJob
        def perform(record_id)
          record = Record.find(record_id)

          # Replace a specific DOM element
          Turbo::StreamsChannel.broadcast_replace_to(
            "record_\#{record.id}_status",
            target: "status_indicator",
            partial: "records/status",
            locals: { record: record, message: "Processing..." }
          )

          # Append content
          Turbo::StreamsChannel.broadcast_append_to(
            "chat_\#{chat.id}",
            target: "messages",
            html: "<div>New message</div>"
          )
        end
      end
      ```

      ### View Setup
      ```erb
      <%%= turbo_stream_from "record_\#{@record.id}_status" %>
      <div id="status_indicator">
        <%%= render "records/status", record: @record %>
      </div>
      ```

      The key insight: the view subscribes to a named stream, and the job
      broadcasts to that same stream. ActionCable handles the WebSocket
      connection automatically. No custom channel code needed.
    CONTENT
  }
]

entries_data.each do |data|
  unless Entry.exists?(title: data[:title])
    entry = Entry.create!(data)
    puts "  Created: #{entry.title} (#{entry.entry_type})"
  else
    puts "  Skipped (exists): #{data[:title]}"
  end
end

puts "\nDone! #{Entry.count} total entries."
