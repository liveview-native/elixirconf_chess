board_input = Axon.input("board", shape: {nil, 8, 8, 12})
valid_moves_mask_input = Axon.input("valid_moves_mask", shape: {nil, 4096})
# meta_input = Axon.input("meta", shape: {nil, 2})

# board input is a tensor that contains channels for
# pawn, rook, knight, bishop, queen and king for white and black, in this order.
# 1 represents that the given (piece, color) combination is present in that position

conv_batch_norm = fn layer, num_filters, kernel_size, padding, activation, kernel_dilation ->
  layer
  |> Axon.conv(num_filters,
    kernel_size: kernel_size,
    padding: padding,
    activation: :linear,
    kernel_dilation: kernel_dilation
  )
  |> Axon.batch_norm()
  |> Axon.activation(activation)
end

res_net = fn input, num_filters, kernel_size ->
  first =
    Axon.conv(input, num_filters, kernel_size: kernel_size, padding: :same, activation: :relu)

  first
  |> Axon.conv(num_filters, kernel_size: kernel_size, padding: :same, activation: :linear)
  |> Axon.add(first)
  |> Axon.relu()
  |> Axon.batch_norm()
end

two_resnet = fn kernel_size ->
  board_input
  |> res_net.(32, kernel_size)
  |> res_net.(32, kernel_size)
end

core =
  Enum.map([3, 7], two_resnet)
  |> Axon.concatenate(axis: -1)
  |> res_net.(64, 3)
  |> res_net.(64, 3)
  |> Axon.conv(256, kernel_size: 8, feature_group_size: 64, activation: :linear)
  |> Axon.batch_norm()
  |> Axon.relu()
  |> Axon.flatten()

# policy = Axon.MixedPrecision.create_policy(params: {:f, 32}, compute: {:f, 16}, output: {:f, 32})

moves_mask =
  valid_moves_mask_input
  |> Axon.reshape({:batch, 64, 64})
  |> Axon.dense(512, activation: :relu)
  |> Axon.flatten()
  |> Axon.dense(256, activation: :relu)

model =
  core
  # |> Axon.concatenate(moves_mask)
  |> Axon.dense(256, activation: :relu)
  |> Axon.dense(256, activation: :relu)
  |> Axon.dense(1, activation: :tanh)
  # |> Axon.nx(&Nx.multiply(&1, 20))
  # |> Axon.multiply(valid_moves_mask_input)
  # |> Axon.nx(fn probs ->
  #   norm_factor = Nx.LinAlg.norm(probs)

  #   probs
  #   |> Nx.divide(Nx.add(norm_factor, 1.0e-7))
  #   # |> Nx.max(0.01)
  # end)
  # |> Axon.MixedPrecision.apply_policy(policy)

Axon.Display.as_graph(model, %{
  "board" => Nx.template({20, 8, 8, 12}, :u8),
  "valid_moves_mask" => Nx.template({20, 4096}, :u8)
})