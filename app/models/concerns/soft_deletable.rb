module SoftDeletable
  extend ActiveSupport::Concern
  # This relies on a `deleted_at` datetime column being present in the model's table.
  # Recommend also indexing that column.

  included do
    scope :with_deleted, -> { unscoped.where(deleted_at: nil) }
    scope :deleted, -> { where.not(deleted_at: nil) }
    scope :not_deleted, -> { where(deleted_at: nil) }
    default_scope { not_deleted }
  end
end
