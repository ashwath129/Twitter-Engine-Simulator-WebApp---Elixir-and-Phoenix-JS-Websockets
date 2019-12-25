defmodule TwitterElixir.EngineServer do
  use GenServer

  # NAME: ASHWATH VENKATARAMAN UFID: 5198-9461
  # NAME: SHASEDHARAN SEKARAN  UFID: 8381-0114

  def start_link() do
    GenServer.start_link(__MODULE__, :ok)
  end

  #########################################################################################################
  # Initialize to start server and create ETS tables for tweets ,users,hashtags and mentions,subscribers
  # Also starts the engine process to start Global server process
  #########################################################################################################

  def init(:ok) do
    # Start Server
    # startServer()


    # Initialize ETS tables
    :ets.new(:userTable, [:set, :public, :named_table])
    :ets.new(:tweetsTable, [:set, :public, :named_table])
    :ets.new(:hmtags, [:set, :public, :named_table])
    :ets.new(:subscriberTable, [:set, :public, :named_table])
    :ets.new(:subscribersForUser, [:set, :public, :named_table])

    # Start server process
    engineProcess()
  end

  #########################################################################################################
  # This starts the main server process that is registered globally as :Engine and used across the server
  # and client for sending and receiving messages using this name
  #########################################################################################################

  def engineProcess() do
    # Spawn process to get pid of server engine
    pid_engine = spawn_link(fn -> middleware_engine() end)
    registerServerEngine(pid_engine)
  end

  def registerServerEngine(pid_engine) do
    # globally register name as Engine
    :global.register_name(:ashwath, pid_engine)
    IO.puts("Server Running...")

    receive do
      _ -> :ok
    end
  end

  #########################################################################################################
  # Start the server in localhost and uses Node module to start and set cookies
  # Will be easy when paired with web sockets
  #########################################################################################################

  def startServer() do
    unless Node.alive?() do
      # inet.getif gives a tuple as a set of IP addresses, we take the first one which is address of the localhost
      # using the hd() and convert the commas into dots for proper ip format

      address = :inet.getif() |> elem(1) |> hd() |> elem(0) |> Tuple.to_list() |> Enum.join(".")
      IO.inspect(address)

      # Using this address we connect it to the client node

      servernode = String.to_atom("server@" <> address)
      Node.start(servernode)
      Node.set_cookie(servernode, :randomcookie)
    end
  end

  #########################################################################################################
  # Main engine function that keeps receiving messages from the client end to distribute and add tweets,
  # mentions,subscribers,query to and from the ETS tables - distribution module
  #########################################################################################################

  def middleware_engine() do
    receive do
      # Register user using pid,userId got from client
      {:registerUser, userId, pid} ->
        handle_registerUser(userId, pid)
        # Send confirmation after adding to ETS table
        send(pid, {:registered})

      # Add tweet to ETS table- either a hashtag# or a mention@
      {:tweet, tweet_Message, userId} ->
        handle_tweet_typeAdd(tweet_Message, userId)

      # Get user tweets from the ETS table,started as a task as we are using message passing between processes
      {:userTweetGet, userId} ->
        Task.start(fn -> handle_getUserTweets(userId) end)

      # To get the list of subscribers for a user
      {:getSubscriberForUser, userId} ->
        Task.start(fn -> getSubscribersForUsers(userId) end)

      # Get subscribers tweets
      {:subscribedTo_tweets, userId} ->
        Task.start(fn -> getTweetsSubscribed(userId) end)

      # Add subscribers to the ETS table, suscribers for users denotes the followers
      {:subscriber_insert, userId, subid} ->
        subscriberListInsert(userId, subid)
        # addition of followers for live purposes
        subscribersForUsers_Insert(subid, userId)

      # query function to search for hashtag#
      {:queryHashtag, hashTag, userId} ->
        Task.start(fn -> handle_searchHashtag(hashTag, userId) end)

      # query function to search for mention @
      {:queryMentions, userId} ->
        Task.start(fn -> handle_searchMention(userId) end)

      # delete user
      {:deleteTweet, userId} ->
        handle_deleteUser(userId)
    end

    # keeps listening
    middleware_engine()
  end

  # Registration function to add userid and process id to usertable and initialize ets tables for
  # their tweets,subscribers
  def handle_registerUser(userId, pid) do
    # initialize tables while registering users with []
    :ets.insert(:userTable, {userId, pid})
    :ets.insert(:tweetsTable, {userId, []})
    :ets.insert(:subscriberTable, {userId, []})

    if :ets.lookup(:subscribersForUser, userId) == [],
      do: :ets.insert(:subscribersForUser, {userId, []})
  end

  # Delete user account
  def handle_deleteUser(userId) do
    # For deletion we just remove the user key from the ets table,lookup then gives []
    :ets.delete(:userTable, userId)
    :ets.lookup(:userTable, userId)
  end

  # Get tweets from table for a user id and send list back to the client
  def handle_getUserTweets(userId) do
    [tweetsForId] = :ets.lookup(:tweetsTable, userId)
    tweet_list = elem(tweetsForId, 1)
    uid = findUser(userId)
    send(uid, {:userTweets, tweet_list})
  end

  # Utility module to get subscribers of a user, for testing purposes
  def getSubscribersForUsers(userId) do
    [subscriberList] = :ets.lookup(:subscriberTable, userId)
    slist = elem(subscriberList, 1)
    uid = findUser(userId)
    send(uid, {:sendSubscribers, slist})
  end

  # Adds tweets to the tweets ets table and handles it based on whether it is a hashtag or a mention
  def handle_tweet_typeAdd(tweet_Message, userId) do
    [getTweets] = :ets.lookup(:tweetsTable, userId)
    existinglist = elem(getTweets, 1)
    existinglist = [tweet_Message | existinglist]
    :ets.insert(:tweetsTable, {userId, existinglist})
    handle_hashtags(tweet_Message)
    handle_mentiontags(tweet_Message)
    handle_liveWall(userId, tweet_Message)
  end

  # Adds subscribers to the subscribers ets table
  def subscriberListInsert(userId, subid) do
    IO.puts("SubscriberListInsertFunction")
    [sublist] = :ets.lookup(:subscriberTable, userId)
    existinglist = elem(sublist, 1)
    existinglist = [subid | existinglist]
    :ets.insert(:subscriberTable, {userId, existinglist})
  end

  # Followers addition to corresponding user
  def subscribersForUsers_Insert(userId, subscribedtoUser) do
    if :ets.lookup(:subscribersForUser, userId) == [],
      do: :ets.insert(:subscribersForUser, {userId, []})

    [subForUser] = :ets.lookup(:subscribersForUser, userId)
    existinglist = elem(subForUser, 1)
    existinglist = [subscribedtoUser | existinglist]
    :ets.insert(:subscribersForUser, {userId, existinglist})
  end

  # function to get tweets of the subscribed user,also used for retweet
  def getTweetsSubscribed(userId) do
    # first we get list of subscriber of userId
    listSubscribers = listOfSubscribers(userId)
    listSubscribers = List.flatten(listSubscribers)
    IO.inspect(listSubscribers)
    # Next we get their tweets to be sent
    rtList = listTweetsS(listSubscribers, [])
    IO.inspect(rtList)
    send(findUser(userId), {:retweetList, rtList})
  end

  def listTweetsS([hd | tl], tweetlist) do
    # Take the first element , retrieve its tweets and the other elements recursively
    tweetlist = tweetsRetrieveFromTable(hd) ++ tweetlist
    listTweetsS(tl, tweetlist)
  end

  def listTweetsS([], tweetlist), do: tweetlist

  def listOfSubscribers(userId) do
    [subscriberList] = :ets.lookup(:subscriberTable, userId)
    elem(subscriberList, 1)
  end

  # Function to retrieve all tweets from the tweets table
  def tweetsRetrieveFromTable(userId) do
    if :ets.lookup(:tweetsTable, userId) == [] do
      []
    else
      [tweetList] = :ets.lookup(:tweetsTable, userId)
      elem(tweetList, 1)
    end
  end

  # Query functionality that sends back a specific hashtag tweet to the client pertaining
  # to the corresponding userId
  def handle_searchHashtag(hashTag, userId) do
    [hashtagList] =
      if :ets.lookup(:hmtags, hashTag) != [] do
        :ets.lookup(:hmtags, hashTag)
      else
        [{"#", []}]
      end

    hashtaglist = elem(hashtagList, 1)
    uid = findUser(userId)
    send(uid, {:get_hashTags, hashtaglist})
  end

  # Query functionality that sends a mention to the client pertaining to the userId
  # Hashtags# and mentions@ are in one ets table - hmtags, mentioned tags are filtered
  # by lookup on the "@" symbol in the ets table
  def handle_searchMention(userId) do
    # check if @<userId> is found in the hmtags ets table
    IO.inspect(userId)

    [mentionsList] =
      if :ets.lookup(:hmtags, "@" <> userId) != [] do
        :ets.lookup(:hmtags, "@" <> userId)
      else
        [{"#", []}]
      end

    mentions = elem(mentionsList, 1)
    uid = findUser(userId)
    send(uid, {:get_Mentions, mentions})
  end

  # Handles hashtag tweets entry to the ets table, the tweet string is scanned
  # using regular expression to find the # symbol
  def handle_hashtags(tweet_Message) do
    tweets_withHash =
      Regex.scan(~r/\B#[a-zA-Z0-9_]+/, tweet_Message)
      |> Enum.concat()

    Enum.each(tweets_withHash, fn htags ->
      tags_etsEntry(htags, tweet_Message)
    end)
  end

  # Handles mentions tweets entry to the ets table, the tweet string is scanned
  # using regular expression to find the @ symbol
  def handle_mentiontags(tweet_Message) do
    tweets_withMention =
      Regex.scan(~r/\B@[a-zA-Z0-9_]+/, tweet_Message)
      |> Enum.concat()

    Enum.each(tweets_withMention, fn mtags ->
      tags_etsEntry(mtags, tweet_Message)
      #  l_mtags = String.length(mtags) - 1
      #  uid = String.slice(mtags, 1, l_mtags)
      #  f_uid = findUser(uid)
      #  addToLiveTweet(f_uid, tweet_Message)

      # We do this since our live view gets tweets of users subscribed to or mentioned by other users
    end)
  end

  # general module to add the tag whether is it is a hash tag or a mention in to the ets table hmtags
  def tags_etsEntry(tagType, tweet_Message) do
    [hashmentionList] =
      if :ets.lookup(:hmtags, tagType) != [] do
        :ets.lookup(:hmtags, tagType)
      else
        [nil]
      end

    if hashmentionList == nil do
      :ets.insert(:hmtags, {tagType, [tweet_Message]})
    else
      existingtList = elem(hashmentionList, 1)
      existingtList = [tweet_Message | existingtList]
      :ets.insert(:hmtags, {tagType, existingtList})
    end
  end

  # Module for the live feed of tweets(mentions) posted by followers or subscribers about them
  def handle_liveWall(userId, tweet_Message) do
    [{_, getfollowers}] = :ets.lookup(:subscribersForUser, userId)

    Enum.each(getfollowers, fn f ->
      f_uid = findUser(f)
      addToLiveTweet(f_uid, tweet_Message)
    end)
  end

  def addToLiveTweet(f_uid, tweet_Message) do
    if f_uid != nil, do: send(f_uid, {:livetweets, tweet_Message})
  end

  # Utility function to find the correspoding user based on its userId from the ets table lookup
  def findUser(userId) do
    userIdList = :ets.lookup(:userTable, userId)

    if userIdList == [] do
      nil
    else
      [tuple] = userIdList
      elem(tuple, 1)
    end

    # hd(userIdList)
  end
end
