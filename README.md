# AI DevLog

An AI-powered developer knowledge base built with Ruby on Rails. Paste code snippets, error logs, solutions, and notes — AI automatically categorizes, tags, summarizes, and creates embeddings for semantic search. Ask questions about your past entries using RAG (Retrieval-Augmented Generation).

## Key Features

- **Smart Entry Management** — Create entries for code snippets, error logs, solutions, notes, and TILs (Today I Learned)
- **AI Auto-Processing Pipeline** — Background jobs automatically generate summaries, extract tags, create embeddings, and find related entries
- **RAG Search** — Ask natural language questions; AI retrieves relevant entries via cosine similarity and generates contextual answers with streaming responses
- **Real-time Updates** — Turbo Streams broadcast AI processing status in real-time
- **Tag Cloud** — AI-generated and manual tags with filtering

## Tech Stack

| Layer | Technology |
|-------|-----------|
| Framework | Ruby on Rails 7.1 |
| Frontend | Hotwire (Turbo Frames + Turbo Streams) + StimulusJS |
| Database | PostgreSQL |
| AI/LLM | RubyLLM gem (OpenAI, Anthropic, etc.) |
| Embeddings | text-embedding-3-small (1536 dims), cosine similarity |
| Background Jobs | Solid Queue |
| CSS | Tailwind CSS |
| Markdown | Redcarpet + Rouge (syntax highlighting) |

## Architecture

```
Entry Created
    |
    v
EntryProcessingJob (Solid Queue)
    |
    ├── 1. Generate Summary (LLM)
    ├── 2. Extract Tags (LLM)
    ├── 3. Create Embedding (text-embedding-3-small)
    └── 4. Find Related Entries (cosine similarity)
    |
    v
Turbo Streams → Real-time UI updates

RAG Search Flow:
    User Question
        |
        v
    Embed Question → Cosine Similarity Search → Top 5 Entries
        |
        v
    Build Context → LLM with Streaming → Turbo Streams → UI
```

## Setup

### Prerequisites
- Ruby 3.2+
- PostgreSQL 14+
- OpenAI API key (or Anthropic)

### Installation

```bash
git clone <repo-url>
cd ai_devlog
bundle install
```

### Database

```bash
bin/rails db:create db:migrate db:seed
```

### API Key

Set your OpenAI API key:

```bash
export OPENAI_API_KEY=sk-your-key-here
```

Or use Rails credentials:
```bash
EDITOR="code --wait" bin/rails credentials:edit
# Add: openai_api_key: sk-your-key-here
```

### Run

```bash
bin/dev
```

This starts the Rails server, Tailwind CSS watcher, and Solid Queue job worker.

Visit `http://localhost:3000`

## Project Structure

```
app/
├── controllers/
│   ├── dashboard_controller.rb    # Stats, tag cloud, recent entries
│   ├── entries_controller.rb      # CRUD with Turbo Stream responses
│   ├── search_controller.rb       # RAG Q&A with streaming
│   └── tags_controller.rb         # Tag browsing and filtering
├── jobs/
│   ├── entry_processing_job.rb    # AI pipeline: summarize → tag → embed → relate
│   └── rag_stream_job.rb          # Streamed RAG responses via Turbo
├── models/
│   ├── concerns/embeddable.rb     # Reusable cosine similarity concern
│   ├── entry.rb                   # Core model with enums, scopes, callbacks
│   ├── tag.rb                     # With counter cache, normalization
│   └── ...
├── services/
│   └── rag_search_service.rb      # RAG: embed query → search → build context → ask LLM
├── javascript/controllers/
│   ├── auto_resize_controller.js  # Auto-expanding textarea
│   ├── tag_input_controller.js    # Tag pill input UI
│   ├── copy_code_controller.js    # Copy code to clipboard
│   └── search_form_controller.js  # Search form handling
└── views/                         # Turbo Frames, Turbo Streams, ERB templates
```

## Design Decisions

1. **Embeddings stored as JSONB in PostgreSQL** — No external vector DB needed. Cosine similarity computed via SQL for simplicity. Scales well for personal knowledge bases.

2. **Single orchestrator job** — `EntryProcessingJob` runs all 4 AI steps sequentially rather than chaining separate jobs. Simpler to reason about, with `retry_on` for transient API failures.

3. **RAG service as a PORO** — Separates retrieval, context building, and LLM interaction into a testable service object. Keeps controllers thin.

4. **Turbo Streams from background jobs** — Real-time UI updates without custom WebSocket code. Idiomatic Rails approach.

5. **Embeddable concern** — Reusable module for any model that needs vector similarity search.

6. **Counter cache on tags** — Avoids N+1 count queries when rendering the tag cloud.
