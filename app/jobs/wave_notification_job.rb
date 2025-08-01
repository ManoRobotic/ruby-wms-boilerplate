class WaveNotificationJob < ApplicationJob
  queue_as :notifications

  def perform(wave, event_type, error_message = nil)
    return unless wave.is_a?(Wave)

    case event_type
    when "released"
      notify_wave_released(wave)
    when "completed"
      notify_wave_completed(wave)
    when "error"
      notify_wave_error(wave, error_message)
    when "started"
      notify_wave_started(wave)
    end
  end

  private

  def notify_wave_released(wave)
    Rails.logger.info "Wave #{wave.name} has been released with #{wave.pick_lists.count} pick lists"

    # Here you could send emails, Slack notifications, etc.
    # For now, just log the event
    create_system_notification(
      wave,
      "Wave Released",
      "Wave #{wave.name} has been released and is ready for picking. #{wave.pick_lists.count} pick lists created."
    )
  end

  def notify_wave_completed(wave)
    Rails.logger.info "Wave #{wave.name} has been completed"

    metrics = WaveManagementService.new(wave.warehouse).wave_metrics(wave)

    message = "Wave #{wave.name} completed successfully. " \
              "Duration: #{metrics[:actual_duration]} minutes, " \
              "Efficiency: #{metrics[:efficiency_score]}%"

    create_system_notification(wave, "Wave Completed", message)
  end

  def notify_wave_started(wave)
    Rails.logger.info "Wave #{wave.name} has been started"

    create_system_notification(
      wave,
      "Wave Started",
      "Wave #{wave.name} picking has started. #{wave.total_orders} orders, #{wave.total_items} items."
    )
  end

  def notify_wave_error(wave, error_message)
    Rails.logger.error "Wave #{wave.name} encountered an error: #{error_message}"

    create_system_notification(
      wave,
      "Wave Error",
      "Wave #{wave.name} failed to process: #{error_message}",
      "error"
    )
  end

  def create_system_notification(wave, title, message, severity = "info")
    # This is a placeholder for a notification system
    # You could implement this as a SystemNotification model or integrate with external services

    Rails.logger.info "NOTIFICATION [#{severity.upcase}] #{title}: #{message}"

    # Example of what you might store in a notifications table:
    # SystemNotification.create!(
    #   title: title,
    #   message: message,
    #   severity: severity,
    #   related_type: 'Wave',
    #   related_id: wave.id,
    #   warehouse: wave.warehouse,
    #   admin: wave.admin
    # )
  end
end
