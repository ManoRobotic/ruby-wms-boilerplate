class SerialConnectionChannel < ApplicationCable::Channel
  # Called when the consumer has successfully
  # become a subscriber of this channel.
  def subscribed
    # For a robust system, you would authenticate the user or device here.
    # For now, we'll use a device_id passed from the client.
    device_id = params[:device_id]

    if device_id.present?
      # stream_for is a secure way to create a private stream for a specific model or ID.
      # This ensures that data for one device isn't broadcast to another.
      stream_for device_id
      puts "Client subscribed to SerialConnectionChannel with device_id: #{device_id}"
    else
      # Reject the connection if no device_id is provided.
      reject
      puts "Subscription rejected. No device_id provided."
    end
  end

  # This method is called when a client sends data to the channel.
  # It acts as a router, forwarding messages between the Python client and the JS client.
  def receive(data)
    device_id = params[:device_id]
    
    # We broadcast the received data to the private stream for this device.
    # The other client connected with the same device_id will receive it.
    # The 'data' payload should contain everything needed, like an 'action' key
    # to differentiate between message types (e.g., 'weight_update', 'print_label').
    SerialConnectionChannel.broadcast_to(device_id, data)
    puts "Broadcasting data to #{device_id}: #{data.inspect}"
  end

  def unsubscribed
    # Any cleanup needed when channel is unsubscribed
    puts "Client with device_id: #{params[:device_id]} unsubscribed."
  end
end
