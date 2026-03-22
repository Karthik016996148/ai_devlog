# AI DevLog

An AI-powered developer knowledge base built with Ruby on Rails. Paste code snippets, error logs, solutions, and notes — AI automatically summarizes, tags, embeds, and finds related entries. Search your knowledge base using RAG (Retrieval-Augmented Generation).

**Live Demo:** [https://ai-devlog.onrender.com](https://ai-devlog.onrender.com)

## What Does This Project Do?

AI DevLog is a **personal developer knowledge base** that solves the problem every developer faces: *"I solved this exact error 3 months ago, but I can't remember how."*

Instead of losing solutions in browser bookmarks, Slack threads, or scattered notes, you paste your code snippets, error logs, solutions, and TILs into AI DevLog. The AI automatically:

1. **Summarizes** each entry into a concise 1-2 sentence insight
2. **Tags** entries with relevant technical terms (e.g., `postgresql`, `n+1-query`, `docker`)
3. **Creates embeddings** — converts text into 1536-dimension vectors for semantic search
4. **Finds related entries** — discovers connections between your past entries via cosine similarity

Then you can **search your entire knowledge base in natural language**. Ask "How did I fix the Docker OOM error?" and AI DevLog retrieves the exact entry you wrote, quotes it directly, and shows the source.

## How It Boosts Developer Productivity

| Without AI DevLog | With AI DevLog |
|---|---|
| Scroll through old Slack messages for 20 min | Search "redis connection error" → instant result |
| Re-Google the same error you fixed last month | Your past fix is auto-retrieved with context |
| Manually organize bookmarks and notes | AI auto-tags and categorizes everything |
| Forget the context around a code snippet | AI summary preserves the key insight |
| No connection between related problems | Vector similarity auto-links related entries |

**Time saved per lookup: ~15-30 minutes.** Over weeks, this compounds into hours of recovered productivity.

## How Ruby on Rails Powers This

Rails is not just "the web framework" here — it's the **integration layer** that makes the entire AI pipeline possible with minimal code:

### 1. ActiveRecord + PostgreSQL = No External Vector DB
```ruby
# Embeddings stored as JSONB right in PostgreSQL
t.jsonb "embedding"  # 1536-dimension vector

# Cosine similarity computed via SQL — no Pinecone, no Redis, no extra infra
Entry.where("title ILIKE ?", "%redis%").includes(:tags)
```
Other stacks would need a separate vector database (Pinecone, Weaviate). Rails keeps everything in one PostgreSQL database.

### 2. Background Jobs = Async AI Pipeline
```ruby
# One callback triggers the entire AI pipeline
after_create_commit :enqueue_ai_processing

# EntryProcessingJob orchestrates 4 OpenAI API calls sequentially
# with retry_on for transient failures and real-time status broadcasts
```
Rails' Active Job abstraction means switching from `async` to `solid_queue` to `sidekiq` is a one-line config change.

### 3. Hotwire = Real-time UI Without a SPA
```ruby
# Background job broadcasts live status to the browser
Turbo::StreamsChannel.broadcast_replace_to(
  "entry_#{entry.id}_processing",
  target: "entry_#{entry.id}_status",
  partial: "entries/processing_status"
)
```
No React. No Vue. No WebSocket boilerplate. The view subscribes, the job broadcasts. Rails handles the rest.

### 4. Service Objects = Clean AI Logic
```ruby
# RAG search is a plain Ruby class — testable, composable, framework-agnostic
class RagSearchService
  def ask_sync(question)
    entries = search_entries(question)       # SQL search
    answer = generate_answer(question, entries)  # LLM call
    { response: answer, sources: entries }
  end
end
```
Thin controllers, fat services. The AI logic is isolated from HTTP concerns.

### 5. Convention Over Configuration = Speed
```bash
rails new ai_devlog --database=postgresql --css=tailwind
rails generate model Entry title:string content:text embedding:jsonb
```
From zero to a deployed AI app in one sitting. Migrations, routes, credentials, asset pipeline — Rails handles the scaffolding so you focus on the AI logic.

## Key Features

- **AI Auto-Processing Pipeline** — Background jobs generate summaries, extract tags, create vector embeddings, and discover related entries
- **RAG-Powered Search** — Ask natural language questions; AI retrieves relevant entries and generates contextual answers
- **Real-time UI** — Turbo Streams broadcast processing status updates live from background jobs
- **Hybrid Search** — Combines keyword matching (title, content, tags) with vector similarity for accurate retrieval
- **Smart Tagging** — AI-generated and manual tags with counter-cached tag cloud
- **Markdown + Syntax Highlighting** — Code entries rendered with Redcarpet and Rouge with copy-to-clipboard
- **5 Stimulus Controllers** — Auto-resize textarea, tag pill input, copy code, search form, markdown preview

## Tech Stack

| Layer | Technology |
|-------|-----------|
| Framework | Ruby on Rails 7.1 |
| Frontend | Hotwire (Turbo Streams + Turbo Frames) |
| JavaScript | StimulusJS (5 controllers) |
| Database | PostgreSQL |
| Vector Search | JSONB embeddings with cosine similarity |
| AI/LLM | RubyLLM gem (OpenAI gpt-4.1-mini) |
| Embeddings | text-embedding-3-small (1536 dimensions) |
| Background Jobs | Solid Queue / Async adapter |
| CSS | Tailwind CSS v4 |
| Markdown | Redcarpet + Rouge |
| Deployment | Render.com |

## Architecture

```
Entry Created
      │
      ▼
EntryProcessingJob (Background)
      │
      ├── 1. Summarize (gpt-4.1-mini)
      ├── 2. Auto-Tag  (gpt-4.1-mini)
      ├── 3. Embed     (text-embedding-3-small)
      └── 4. Find Related Entries (cosine similarity)
      │
      ▼
Turbo Streams → Real-time UI Update


RAG Search Flow:

User Question → Search title/content/tags → Matching Entries → LLM summarizes → Answer + Sources
```

## Project Structure

```
app/
├── controllers/
│   ├── dashboard_controller.rb      # Stats, tag cloud, recent entries
│   ├── entries_controller.rb        # Full CRUD + reprocess
│   ├── search_controller.rb         # RAG search interface
│   └── tags_controller.rb           # Tag browsing and filtering
├── jobs/
│   └── entry_processing_job.rb      # 4-step AI pipeline with broadcasts
├── models/
│   ├── concerns/embeddable.rb       # Reusable cosine similarity concern
│   ├── entry.rb                     # Enums, scopes, callbacks, associations
│   ├── tag.rb                       # Counter cache, normalization
│   ├── chat.rb / message.rb         # RubyLLM integration
│   └── related_entry.rb             # Self-referential similarity links
├── services/
│   └── rag_search_service.rb        # Search + LLM answer generation
├── helpers/
│   ├── markdown_helper.rb           # Redcarpet + Rouge rendering
│   └── entry_helper.rb              # Type badges, status icons
├── javascript/controllers/
│   ├── auto_resize_controller.js    # Auto-expanding textarea
│   ├── tag_input_controller.js      # Pill-based tag input
│   ├── copy_code_controller.js      # Copy code blocks to clipboard
│   ├── search_form_controller.js    # Search form handling
│   └── markdown_preview_controller.js # Edit/Preview toggle
└── views/
    ├── entries/                     # CRUD views + Turbo Stream templates
    ├── search/                      # Chat-style RAG interface
    ├── dashboard/                   # Stats + tag cloud
    └── tags/                        # Tag index + filtered entries
```

## Design Decisions

1. **Embeddings in PostgreSQL (JSONB)** — No external vector DB needed. Cosine similarity computed via SQL. Practical for personal-scale knowledge bases.

2. **Single orchestrator job** — `EntryProcessingJob` runs all 4 AI steps sequentially with `retry_on` for transient API failures and per-step status broadcasts.

3. **RAG service as a PORO** — `RagSearchService` encapsulates the search + LLM pipeline. Keeps controllers thin and logic testable.

4. **Turbo Streams from background jobs** — Real-time UI without custom WebSocket channels. Idiomatic Rails 8 pattern.

5. **Embeddable concern** — Extracted into a reusable module. Any model can include it to gain vector search.

6. **Hybrid search** — Combines SQL keyword matching with vector similarity for accurate retrieval regardless of entry processing status.

## Local Setup

### Prerequisites
- Ruby 3.2+
- PostgreSQL 14+
- OpenAI API key

### Installation

```bash
git clone https://github.com/Karthik016996148/ai_devlog.git
cd ai_devlog
bundle install
```

### Database

```bash
bin/rails db:create db:migrate db:seed
bin/rails entries:process_all  # Process all entries through AI pipeline
```

### API Key

```bash
export OPENAI_API_KEY=your-key-here
```

### Run

```bash
bin/dev
```

## Deployment

Deployed on [Render.com](https://render.com) using the included `render.yaml` blueprint.

Required environment variables on Render:
- `OPENAI_API_KEY`
- `RAILS_MASTER_KEY`

## Contributors

<table>
  <tr>
    <td align="center">
      <a href="https://github.com/Karthik016996148">
        <b>Karthik</b>
      </a>
      <br />
      <sub>Creator & Maintainer</sub>
    </td>
  </tr>
</table>
