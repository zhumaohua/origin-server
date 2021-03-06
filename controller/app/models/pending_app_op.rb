# Class to represent pending operations that need to occur for the {Application}
# @!attribute [r] application
#   @return [Application] {Application} that this operation needs to be performed on.
# @!attribute [r] op_type
#   @return [Symbol] Operation type
# @!attribute [r] state
#   @return [Symbol] Operation state. One of init, queued or completed
# @!attribute [r] arguments
#   @return [Hash] Arguments hash
# @!attribute [r] retry_count
#   @return [Integer] Number of times this operation has been attempted
class PendingAppOp
  include Mongoid::Document
  embedded_in :pending_app_op_group, class_name: PendingAppOpGroup.name
  field :op_type,           type: Symbol
  field :state,             type: Symbol,   default: :init
  field :args,              type: Hash
  field :prereq,            type: Array
  field :retry_count,       type: Integer,  default: 0
  field :retry_rollback_op, type: Moped::BSON::ObjectId
  field :saved_values,      type: Hash, default: {}

  def args
    self.attributes["args"] || {}
  end

  def prereq
    self.attributes["prereq"] || []
  end

  # Sets the [PendingDomainOps] Domain level operation that spawned this operation.
  #
  # == Parameters:
  # op::
  #   The {PendingDomainOps} object.
  def parent_op=(op)
    self.parent_op_id = op._id unless op.nil?
  end

  # @return [PendingDomainOps] Domain level operation that spawned this operation.  
  def parent_op
    self.application.domain.pending_ops.find(self.parent_op_id) unless parent_op_id.nil?
  end

  # Marks the operation as completed on the parent operation.
  def completed
    set_state(:completed)
    parent_op.child_completed(application) unless parent_op_id.nil?
  end

  # the new_state needs to be a symbol
  def set_state(new_state)
    failure_message = "Failed to set pending_op #{self._id.to_s} state to #{new_state.to_s} for application #{self.pending_app_op_group.application.name}"
    updated_op = update_with_retries(5, failure_message) do |current_app, current_op_group, current_op, op_group_index, op_index|
      Application.where({ "_id" => current_app._id, "pending_op_groups.#{op_group_index}._id" => current_op_group._id, "pending_op_groups.#{op_group_index}.pending_ops.#{op_index}._id" => current_op._id }).update({"$set" => { "pending_op_groups.#{op_group_index}.pending_ops.#{op_index}.state" => new_state }})
    end
    
    # set the state in the object in mongoid memory for access by the caller
    self.state = updated_op.state
  end

  def update_with_retries(num_retries, failure_message, &block)
    retries = 0
    success = false

    current_op = self
    current_op_group = self.pending_app_op_group
    current_app = self.pending_app_op_group.application

    # find the index and do an atomic update
    op_group_index = current_app.pending_op_groups.index(current_op_group)
    op_index = current_app.pending_op_groups[op_group_index].pending_ops.index(current_op)

    while retries < num_retries
      retval = block.call(current_app, current_op_group, current_op, op_group_index, op_index)

      # the op needs to be reloaded to find the updated index
      current_app = Application.find_by(_id: current_app._id)
      current_op_group = current_app.pending_op_groups.find_by(_id: current_op_group._id)
      op_group_index = current_app.pending_op_groups.index(current_op_group)
      current_op = current_app.pending_op_groups[op_group_index].pending_ops.find_by(_id: current_op._id)
      op_index = current_app.pending_op_groups[op_group_index].pending_ops.index(current_op)
      retries += 1

      if retval["updatedExisting"]
        success = true
        break
      end
    end

    # log the details in case we cannot update the pending_op
    unless success
      Rails.logger.error(failure_message)
    end
    
    return current_op
  end
end
