defmodule DataIoFunTest do
  use ExUnit.Case
  doctest Snapex7

  setup do
    {:ok, pid} = Snapex7.Client.start_link()
    Snapex7.Client.connect_to(pid, ip: "192.168.0.1", rack: 0, slot: 1)
    {:ok, state} = :sys.get_state(pid) |> Map.fetch(:state)
    %{pid: pid, status: state}
  end

  test "read/write_area function", state do
    case state.status do
      :connected ->
        resp =
          Snapex7.Client.write_area(state.pid,
            area: :DB,
            word_len: :byte,
            start: 2,
            amount: 4,
            db_number: 1,
            data: <<0x42, 0xCB, 0x00, 0x00>>
          )

        assert resp == :ok

        {:ok, resp_bin} =
          Snapex7.Client.read_area(state.pid,
            area: :DB,
            word_len: :byte,
            start: 2,
            amount: 4,
            db_number: 1
          )

        assert resp_bin == <<0x42, 0xCB, 0x00, 0x00>>

        resp =
          Snapex7.Client.write_area(state.pid,
            area: :DB,
            word_len: :byte,
            start: 2,
            amount: 4,
            db_number: 1,
            data: <<0x42, 0xCA, 0x00, 0x00>>
          )

        assert resp == :ok

        {:ok, resp_bin} =
          Snapex7.Client.read_area(state.pid,
            area: :DB,
            word_len: :byte,
            start: 2,
            amount: 4,
            db_number: 1
          )

        assert resp_bin == <<0x42, 0xCA, 0x00, 0x00>>

      _ ->
        IO.puts("(#{__MODULE__}) Not connected")
    end
  end

  test "db_read/write function", state do
    case state.status do
      :connected ->
        resp =
          Snapex7.Client.db_write(state.pid,
            start: 2,
            amount: 4,
            db_number: 1,
            data: <<0x42, 0xCB, 0x00, 0x00>>
          )

        assert resp == :ok

        {:ok, resp_bin} =
          Snapex7.Client.db_read(state.pid,
            start: 2,
            amount: 4,
            db_number: 1
          )

        assert resp_bin == <<0x42, 0xCB, 0x00, 0x00>>

        resp =
          Snapex7.Client.db_write(state.pid,
            start: 2,
            amount: 4,
            db_number: 1,
            data: <<0x42, 0xCA, 0x00, 0x00>>
          )

        assert resp == :ok

        {:ok, resp_bin} =
          Snapex7.Client.db_read(state.pid,
            start: 2,
            amount: 4,
            db_number: 1
          )

        assert resp_bin == <<0x42, 0xCA, 0x00, 0x00>>

      _ ->
        IO.puts("(#{__MODULE__}) Not connected")
    end
  end

  test "ab_read/write function", state do
    case state.status do
      :connected ->
        resp =
          Snapex7.Client.ab_write(state.pid,
            start: 0,
            amount: 1,
            data: <<0x0F>>
          )

        assert resp == :ok

        {:ok, resp_bin} =
          Snapex7.Client.ab_read(state.pid,
            start: 0,
            amount: 1
          )

        assert resp_bin == <<0x0F>>

        resp =
          Snapex7.Client.ab_write(state.pid,
            start: 0,
            amount: 1,
            data: <<0x00>>
          )

        assert resp == :ok

        {:ok, resp_bin} =
          Snapex7.Client.ab_read(state.pid,
            start: 0,
            amount: 1
          )

        assert resp_bin == <<0x00>>

      _ ->
        IO.puts("(#{__MODULE__}) Not connected")
    end
  end

  # eb_write doesn't make sense...
  test "eb_read/write function", state do
    case state.status do
      :connected ->
        resp =
          Snapex7.Client.eb_write(state.pid,
            start: 0,
            amount: 1,
            data: <<0x0F>>
          )

        assert resp == :ok

        {:ok, resp_bin} =
          Snapex7.Client.eb_read(state.pid,
            start: 0,
            amount: 1
          )

        assert resp_bin == <<0x08>>

      _ ->
        IO.puts("(#{__MODULE__}) Not connected")
    end
  end

  test "mb_read/write function", state do
    case state.status do
      :connected ->
        resp =
          Snapex7.Client.mb_write(state.pid,
            start: 0,
            amount: 1,
            data: <<0x0F>>
          )

        assert resp == :ok

        {:ok, resp_bin} =
          Snapex7.Client.mb_read(state.pid,
            start: 0,
            amount: 1
          )

        assert resp_bin == <<0x0F>>

        resp =
          Snapex7.Client.mb_write(state.pid,
            start: 0,
            amount: 1,
            data: <<0x00>>
          )

        assert resp == :ok

        {:ok, resp_bin} =
          Snapex7.Client.mb_read(state.pid,
            start: 0,
            amount: 1
          )

        assert resp_bin == <<0x00>>

      _ ->
        IO.puts("(#{__MODULE__}) Not connected")
    end
  end

  # PLC s7-1200 doesn't supports this functions.
  test "tm_read/write function", state do
    case state.status do
      :connected ->
        resp =
          Snapex7.Client.tm_write(state.pid,
            start: 0,
            amount: 1,
            data: <<0x0F, 0x00>>
          )

        assert resp == {:error, %{eiso: nil, es7: :errCliAddressOutOfRange, etcp: nil}}

        resp =
          Snapex7.Client.tm_read(state.pid,
            start: 0,
            amount: 1
          )

        assert resp == {:error, %{eiso: nil, es7: :errCliAddressOutOfRange, etcp: nil}}

      _ ->
        IO.puts("(#{__MODULE__}) Not connected")
    end
  end

  # PLC s7-1200 doesn't supports this functions.
  test "ct_read/write function", state do
    case state.status do
      :connected ->
        resp =
          Snapex7.Client.ct_write(state.pid,
            start: 0,
            amount: 1,
            data: <<0x0F, 0x00>>
          )

        assert resp == {:error, %{eiso: nil, es7: :errCliAddressOutOfRange, etcp: nil}}

        resp =
          Snapex7.Client.ct_read(state.pid,
            start: 0,
            amount: 1
          )

        assert resp == {:error, %{eiso: nil, es7: :errCliAddressOutOfRange, etcp: nil}}

      _ ->
        IO.puts("(#{__MODULE__}) Not connected")
    end
  end

  test "read/write_multi_vars function", state do
    data1 = %{
      area: :DB,
      word_len: :byte,
      db_number: 1,
      start: 2,
      amount: 4,
      data: <<0x42, 0xCB, 0x20, 0x10>>
    }

    # P0
    data2 = %{
      area: :PA,
      word_len: :byte,
      db_number: 1,
      start: 0,
      amount: 1,
      data: <<0x0F>>
    }

    # DB1
    data3 = %{
      area: :DB,
      word_len: :byte,
      db_number: 1,
      start: 2,
      amount: 4,
      data: <<0x42, 0xCA, 0x00, 0x00>>
    }

    # P0
    data4 = %{
      area: :PA,
      word_len: :byte,
      db_number: 1,
      start: 0,
      amount: 1,
      data: <<0x00>>
    }

    # DB1
    r_data1 = %{
      area: :DB,
      word_len: :byte,
      db_number: 1,
      start: 2,
      amount: 4
    }

    # P0
    r_data2 = %{
      area: :PA,
      word_len: :byte,
      db_number: 1,
      start: 0,
      amount: 1
    }

    # PE0
    r_data3 = %{
      area: :PE,
      word_len: :byte,
      db_number: 1,
      start: 0,
      amount: 1
    }
    case state.status do
      :connected ->
        resp = Snapex7.Client.write_multi_vars(state.pid, data: [data1, data2])
        assert resp == :ok

        resp = Snapex7.Client.read_multi_vars(state.pid, data: [r_data1, r_data2])
        assert resp == {:ok, [<<0x42, 0xCB, 0x20, 0x10>>, <<0x0F>>]}

        resp = Snapex7.Client.write_multi_vars(state.pid, data: [data3, data4])
        assert resp == :ok

        resp = Snapex7.Client.read_multi_vars(state.pid, data: [r_data1, r_data2, r_data3])
        assert resp == {:ok, [<<0x42, 0xCA, 0x00, 0x00>>, <<0x00>>, <<0x08>>]}
      _ ->
        IO.puts("(#{__MODULE__}) Not connected")
    end
  end
end
