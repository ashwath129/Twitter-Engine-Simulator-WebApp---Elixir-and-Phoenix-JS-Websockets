defmodule TwitterWebWeb.ClientChannel do
  use Phoenix.Channel

  # NAME: ASHWATH VENKATARAMAN UFID: 5198-9461
  # NAME: SHASEDHARAN SEKARAN  UFID: 8381-0114

  def join("room:lobby", _message, socket) do
    {:ok, socket}
  end

  def join("room:" <> _private_room_id, _params, _socket) do
    {:error, %{reason: "NotValid"}}
  end

  def handle_in("register", userName, socket) do
    send(:global.whereis_name(:ashwath), {:registerUser, userName, self()})

    receive do
      {:registered} -> IO.puts("Registered User successfully!")
      _ -> :error
    end

    push(socket, "registered", %{"userName" => userName})
    {:reply, :registered, socket}
  end

  def handle_in("subscribe", socketData, socket) do
    userName = socketData["username"]
    usersToSub = socketData["usersToSub"]
    send(:global.whereis_name(:ashwath), {:subscriber_insert, userName, usersToSub})
    push(socket, "subscribed", %{"userName" => userName})
    {:reply, :subscribed, socket}
  end

  def handle_in("addTweet", socketData, socket) do
    tweetText = socketData["tweetText"]
    userName = socketData["username"]
    send(:global.whereis_name(:ashwath), {:tweet, tweetText, userName})
    {:noreply, socket}
  end

  def handle_in("getSubTweet", params, socket) do
    userName = params["username"]
    send(:global.whereis_name(:ashwath), {:subscribedTo_tweets, userName})

    receive do
      {:retweetList, rtlist} ->
        if rtlist != [],
          do: IO.puts("Subscribed by tweets of #{userName} are #{inspect(rtlist)} \n")

        push(socket, "subscribedtoTweets", %{"rtlist" => rtlist})
    end

    {:noreply, socket}
  end

  def handle_in("search_hashtag", params, socket) do
    userName = params["username"]
    hashtagList = params["hashtagList"]
    send(:global.whereis_name(:ashwath), {:queryHashtag, hd(hashtagList), userName})

    receive do
      {:get_hashTags, hashtagsList} ->
        IO.puts(
          "Query Result: Tweets with #{hashtagList} of User #{userName} are #{
            inspect(hashtagsList)
          } \n"
        )

        push(socket, "search_hashtag", %{"hashtagsList" => hashtagsList})
    end

    {:noreply, socket}
  end

  def handle_in("search_mentions", params, socket) do
    userName = params["username"]
    send(:global.whereis_name(:ashwath), {:queryMentions, userName})

    receive do
      {:get_Mentions, mentionsList} ->
        IO.puts(
          "Query Result: Tweets with @mention of User #{userName} are #{inspect(mentionsList)} \n"
        )

        push(socket, "search_mentions", %{"mentionsList" => mentionsList})
    end

    {:noreply, socket}
  end

  def handle_in("getTweets", params, socket) do
    userName = params["username"]
    send(:global.whereis_name(:ashwath), {:userTweetGet, userName})

    receive do
      {:userTweets, tweets} ->
        IO.puts("List of Tweets of User #{userName} are #{inspect(tweets)} \n")
        {"List of Tweets of User #{userName} are #{inspect(tweets)}"}
        push(socket, "tweetsofUser", %{"tweets" => tweets})
    end

    {:noreply, socket}
  end

  def handle_in("RETWEET", params, socket) do
    userName = params["username"]
    rttext = params["rttext"]
    rttext = rttext <> " - This is interesting-RETWEETED"
    send(:global.whereis_name(:ashwath), {:tweet, rttext, userName})

    {:noreply, socket}
  end

  def handle_in("getSubscribers", params, socket) do
    userName = params["username"]
    send(:global.whereis_name(:ashwath), {:getSubscriberForUser, userName})

    receive do
      {:sendSubscribers, slist} ->
        IO.puts("Subscribers of User #{userName} are Users #{inspect(slist)} \n")
        push(socket, "subscriberlist", %{"sublist" => slist})
    end

    {:noreply, socket}
  end
end
