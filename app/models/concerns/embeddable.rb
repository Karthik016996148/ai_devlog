module Embeddable
  extend ActiveSupport::Concern

  included do
    scope :with_embeddings, -> { where.not(embedding: nil) }
  end

  class_methods do
    def search_by_embedding(query_embedding, limit: 5)
      with_embeddings.select("*, #{cosine_similarity_sql(query_embedding)} AS similarity_score")
                     .order(Arel.sql("similarity_score DESC"))
                     .limit(limit)
    end

    private

    def cosine_similarity_sql(query_vec)
      # Cosine similarity computed via PostgreSQL JSONB array operations
      # dot(a,b) / (norm(a) * norm(b))
      query_json = query_vec.to_json
      <<~SQL.squish
        (
          SELECT COALESCE(
            SUM(a.val * b.val) /
            NULLIF(
              SQRT(SUM(a.val * a.val)) * SQRT(SUM(b.val * b.val)),
              0
            ),
            0
          )
          FROM jsonb_array_elements_text(entries.embedding) WITH ORDINALITY AS a(val, idx),
               jsonb_array_elements_text('#{query_json}'::jsonb) WITH ORDINALITY AS b(val, idx)
          WHERE a.idx = b.idx
        )
      SQL
    end
  end

  def similar_records(limit: 5)
    return self.class.none if embedding.nil?
    self.class.where.not(id: id)
         .search_by_embedding(embedding, limit: limit)
  end
end
