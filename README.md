# AI DevLog

An AI-powered developer knowledge base built with Ruby on Rails. Paste code snippets, error logs, solutions, and notes, AI automatically summarizes, tags, embeds, and finds related entries. Search your knowledge base with natural language using RAG (Retrieval-Augmented Generation).

**Live Demo:** [https://ai-devlog.onrender.com](https://ai-devlog.onrender.com)

## Key Features

- **AI Auto-Processing Pipeline** — Background jobs generate summaries, extract tags, create vector embeddings, and discover related entries in real-time
- **RAG-Powered Search** — Ask natural language questions; AI retrieves relevant entries via cosine similarity and streams contextual answers
- **Real-time UI** — Turbo Streams broadcast processing status updates live from background jobs — no page refresh needed
- **Smart Tagging** — AI-generated and manual tags with counter-cached tag cloud
- **Markdown + Syntax Highlighting** — Code entries rendered with Redcarpet and Rouge with copy-to-clipboard
- **5 Stimulus Controllers** — Auto-resize, tag pill input, copy code, search form, markdown preview

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
                    ┌──────────────────┐
                    │   Entry Created  │
                    └────────┬─────────┘
                             │
                             ▼
                ┌────────────────────────┐
                │  EntryProcessingJob    │
                │  (Background Worker)   │
                └────────────┬───────────┘
                             │
            ┌────────────────┼────────────────┐
            │                │                │
            ▼                ▼                ▼
    ┌──────────────┐ ┌──────────────┐ ┌──────────────┐
    │ 1. Summarize │ │ 2. Tag       │ │ 3. Embed     │
    │ (gpt-4.1-    │ │ (gpt-4.1-   │ │ (text-embed- │
    │  mini)       │ │  mini)       │ │  ding-3-sm)  │
    └──────┬───────┘ └──────┬───────┘ └──────┬───────┘
           │                │                │
           └────────────────┼────────────────┘
                            │
                            ▼
                ┌────────────────────────┐
                │ 4. Find Related Entries│
                │ (Cosine Similarity)    │
                └────────────┬───────────┘
                             │
                             ▼
                ┌────────────────────────┐
                │ Turbo Streams →        │
                │ Real-time UI Update    │
                └────────────────────────┘


RAG Search Flow:

    User Question
         │
         ▼
    ┌─────────────┐    ┌──────────────────┐    ┌──────────────┐
    │ Embed Query  │───▶│ Cosine Similarity │───▶│ Top 5 Entries│
    │ (OpenAI)     │    │ Search (JSONB)    │    │ as Context   │
    └─────────────┘    └──────────────────┘    └──────┬───────┘
                                                      │
                                                      ▼
                                              ┌──────────────┐
                                              │ LLM + Stream │
                                              │ via Turbo    │
                                              └──────────────┘
```

## Project Structure

```
app/
├── controllers/
│   ├── dashboard_controller.rb      # Stats, tag cloud, recent entries
│   ├── entries_controller.rb        # Full CRUD + reprocess with Turbo Streams
│   ├── search_controller.rb         # RAG Q&A with streaming responses
│   └── tags_controller.rb           # Tag browsing and filtering
├── jobs/
│   ├── entry_processing_job.rb      # 4-step AI pipeline with real-time broadcasts
│   └── rag_stream_job.rb            # Streamed RAG answers via Turbo Streams
├── models/
│   ├── concerns/embeddable.rb       # Reusable cosine similarity concern
│   ├── entry.rb                     # Enums, scopes, callbacks, associations
│   ├── tag.rb                       # Counter cache, normalization, source tracking
│   ├── chat.rb / message.rb         # RubyLLM acts_as_chat integration
│   └── related_entry.rb             # Self-referential similarity links
├── services/
│   └── rag_search_service.rb        # PORO: embed → search → context → stream LLM
├── helpers/
│   ├── markdown_helper.rb           # Redcarpet + Rouge rendering
│   └── entry_helper.rb              # Type badges, status icons
├── javascript/controllers/
│   ├── auto_resize_controller.js    # Auto-expanding textarea
│   ├── tag_input_controller.js      # Pill-based tag input (comma/Enter)
│   ├── copy_code_controller.js      # Copy code blocks to clipboard
│   ├── search_form_controller.js    # Submit + clear search input
│   └── markdown_preview_controller.js # Edit/Preview toggle
└── views/
    ├── entries/                     # CRUD views + Turbo Stream templates
    ├── search/                      # Chat-style RAG interface
    ├── dashboard/                   # Stats + tag cloud + recent entries
    └── tags/                        # Tag index + filtered entries
```

## Design Decisions

1. **Embeddings in PostgreSQL (JSONB)** — No external vector DB needed. Cosine similarity computed via SQL subquery. Practical for personal-scale knowledge bases and demonstrates understanding of the math behind vector search.

2. **Single orchestrator job** — `EntryProcessingJob` runs all 4 AI steps sequentially. Simpler than chaining jobs, with `retry_on` for transient API failures and per-step status broadcasts.

3. **RAG service as a PORO** — `RagSearchService` encapsulates the full RAG pipeline (embed query → similarity search → context assembly → LLM streaming). Keeps controllers thin and the service testable.

4. **Turbo Streams from background jobs** — Real-time UI without custom WebSocket channels. `Turbo::StreamsChannel.broadcast_*` is idiomatic Rails — the view subscribes, the job broadcasts.

5. **Embeddable concern** — Extracted into a reusable module. Any model can include it to gain vector search capabilities.

6. **Counter cache on tags** — `entries_count` avoids N+1 count queries in the tag cloud. Classic Rails optimization.

7. **Async adapter for free-tier deploy** — Jobs run in-process on Render's free tier (no separate worker dyno). Solid Queue available for production with dedicated workers.

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

Deployed on [Render.com](https://render.com) using the included `render.yaml` blueprint:

```bash
# One-click deploy via Render Blueprint
# render.yaml configures: web service + PostgreSQL database
```

Required environment variables on Render:
- `OPENAI_API_KEY`
- `RAILS_MASTER_KEY`
      </a>
      <br />
      <sub>Creator & Maintainer</sub>
    </td>
  </tr>
</table>
