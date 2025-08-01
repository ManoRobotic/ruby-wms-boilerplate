module StandardCrudResponses
  extend ActiveSupport::Concern

  private

  def handle_create_response(resource, success_path, success_message, failure_view, failure_setup_proc = nil)
    respond_to do |format|
      if resource.save
        format.html { redirect_to success_path, notice: success_message }
        format.json { render :show, status: :created, location: resource }
      else
        failure_setup_proc&.call
        format.html { render failure_view, status: :unprocessable_entity }
        format.json { render json: resource.errors, status: :unprocessable_entity }
      end
    end
  end

  def handle_update_response(resource, success_path, success_message, failure_view, failure_setup_proc = nil)
    respond_to do |format|
      if resource.save
        format.html { redirect_to success_path, notice: success_message }
        format.json { render :show, status: :ok, location: resource }
      else
        failure_setup_proc&.call
        format.html { render failure_view, status: :unprocessable_entity }
        format.json { render json: resource.errors, status: :unprocessable_entity }
      end
    end
  end
end
