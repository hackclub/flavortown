class CreateVoteReasonEmbeddings < ActiveRecord::Migration[8.1]
  def up
    enable_extension "vector"

    create_table :vote_reason_embeddings do |t|
      t.bigint :vote_id, null: false
      t.column :embedding, :vector, limit: 1536, null: false
      t.string :model_version, null: false, default: "text-embedding-3-small"
      t.timestamps
    end

    add_index :vote_reason_embeddings, :vote_id, unique: true
  end

  def down
    drop_table :vote_reason_embeddings
    disable_extension "vector"
  end
end
