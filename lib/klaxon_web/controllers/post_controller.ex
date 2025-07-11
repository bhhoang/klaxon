defmodule KlaxonWeb.PostController do
  alias Klaxon.Activities
  use KlaxonWeb, :controller

  import KlaxonWeb.Plugs
  alias Klaxon.Contents
  alias Klaxon.Contents.Post

  action_fallback KlaxonWeb.FallbackController
  plug :activity_json_response

  def index(conn, _params) do
    with {:ok, profile} <- current_profile(conn),
         {:ok, posts} <-
           Contents.get_posts(profile.uri, conn.assigns[:current_user]) do
      # FIXME: Make title more appropriate.
      render(conn, posts: posts, title: "Posts")
    end
  end

  def new(conn, _params) do
    changeset = Contents.change_post(conn.host, %Post{})
    render(conn, "new.html", changeset: changeset)
  end

  def create(conn, %{"post" => post_params}) do
    with {:ok, profile} <- current_profile(conn),
         {:ok, post} <-
           Contents.insert_local_post(
             post_params,
             profile.id,
             conn.host,
             &Routes.post_url(conn, :show, &1)
           ) do
      conn
      |> put_flash(:info, "Post created successfully.")
      |> redirect(to: Routes.post_path(conn, :show, post))
    else
      {:error, %Ecto.Changeset{} = changeset} ->
        render(conn, "new.html", changeset: changeset)

      {:error, reason} ->
        {:error, reason}
    end
  end

  def show(conn, %{"id" => id}) do
    with {:ok, profile} <- current_profile(conn),
         {:ok, post} <-
           Contents.get_post(profile.uri, id, conn.assigns[:current_user]) do
      likes =
        Activities.get_likes(post.uri)
        |> Enum.filter(fn x -> x.actor end)

      replies =
        Contents.get_context(profile.uri, post.context_uri, conn.assigns[:current_user])
        |> Enum.filter(fn x -> x.id != post.id end)

      render(conn, post: post, title: htmlify_title(post), likes: likes, replies: replies)
    end
  end

  def edit(conn, %{"id" => id}) do
    with {:ok, profile} <- current_profile(conn),
         {:ok, post} <- Contents.get_post(profile.uri, id, conn.assigns[:current_user]) do
      changeset = Contents.change_post(conn.host, post)
      render(conn, "edit.html", post: post, changeset: changeset)
    end
  end

  def update(conn, %{"id" => id, "post" => post_params} = _) do
    with {:ok, profile} <- current_profile(conn),
         {:ok, post} <- Contents.get_post(profile.uri, id, conn.assigns[:current_user]) do
      case Contents.update_local_post(post, post_params, conn.host) do
        {:ok, post} ->
          case post.status do
            :deleted ->
              conn
              |> put_flash(:info, "Post deleted successfully.")
              |> redirect(to: Routes.post_path(conn, :index))

            _ ->
              conn
              |> put_flash(:info, "Post updated successfully.")
              |> redirect(to: Routes.post_path(conn, :show, post))
          end

        {:error, %Ecto.Changeset{} = changeset} ->
          render(conn, "edit.html", post: post, changeset: changeset)
      end
    end
  end

  # def delete(conn, %{"id" => id}) do
  #   post = Contents.get_post!(id)
  #   {:ok, _post} = Contents.delete_post(post)

  #   conn
  #   |> put_flash(:info, "Post deleted successfully.")
  #   |> redirect(to: Routes.post_path(conn, :index))
  # end
end
