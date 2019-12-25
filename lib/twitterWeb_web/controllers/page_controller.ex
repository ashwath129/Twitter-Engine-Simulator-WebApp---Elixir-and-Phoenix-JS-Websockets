defmodule TwitterWebWeb.PageController do
  use TwitterWebWeb, :controller

  def index(conn, _params) do
    render(conn, "index.html")
  end
end
