defmodule TwitterEngine.Client do
    use GenServer

#NAME: ASHWATH VENKATARAMAN UFID: 5198-9461
#NAME: SHASEDHARAN SEKARAN  UFID: 8381-0114

    def start_link(userId,num_msg,subscribeCnt,noOfClients) do
        GenServer.start_link(__MODULE__,[userId,num_msg,subscribeCnt,noOfClients])
    end

	#########################################################################################################
	#Init module to start the client process, sync it to a global registered process, register client based 
	#on the userId, and simulate client based on the no of tweets and subscriber max cnt
	#########################################################################################################
    def init([userId,num_msg,subscribeCnt,noOfClients]) do
        #connect user to twitter server and sync globally
		clientStart()
        :global.sync()
		
		#register users to the twitter server
		registerClient(userId)
        
        #Simulate various user functionalities        
        simulateClient(userId,num_msg,subscribeCnt,noOfClients)
        receive do  _ -> :ok end
    end
	
    #########################################################################################################
	#Start the client in localhost and uses Node module to start and set cookies and connect it with the 
	#server, after it is started. Will be easy when paired with web sockets
	#########################################################################################################
	def clientStart() do
        unless Node.alive?() do
        #inet.getif gives a tuple as a set of IP addresses, we take the first one which is address of the localhost
		#using the hd() and convert the commas into dots for proper ip format
		address = :inet.getif() |> elem(1) |> hd() |> elem(0) |> Tuple.to_list |> Enum.join(".")        
		userNode = String.to_atom("client@" <> address)
        Node.start(userNode)
        Node.set_cookie(userNode,:randomcookie)
		
		#Connecting to the started server process already started
        Node.connect(String.to_atom("server@" <> address))
        end
    end
	
	#########################################################################################################
	#Register twitter user based on its id. Send the :registerUser message to the server :Engine and 
	#receive confirmation message from the Twitter Server Api Engine
	#########################################################################################################
	def registerClient(userId) do
	  
	  #Send register user with userid,pid to the server
	  send(getServerEnginePid(),{:registerUser,userId,self()})
      receive do
	  #receive a registered message and print message in console
      {:registered} -> IO.puts "Registered User #{userId} successfully!"
	  _ -> :error
      end
	end

    #########################################################################################################
	#Simulation of twitter user functionalities - mentions,hashags,normal tweet,retweet,addsubscriber
	#Query for hashtags,mentions,subscribed tweets. The times for each of the queries is calculated to get
	#the performance statistics and send it to the global main process in the main file
	#########################################################################################################
    def simulateClient(userId,num_msg,subscribeCnt,noOfClients) do
       simulateSubscriberAdd(userId,subscribeCnt,noOfClients)	
	   st = System.system_time(:millisecond)
       simulateMention(userId,noOfClients)
       simulateHashTag(userId)
       simulateNormalTweet(userId,num_msg)
	   simulateRetweet(userId)
       #retweet(userId,noOfClients)
       timeForTweets = System.system_time(:millisecond) - st       
	   queryAndPerformance(userId,timeForTweets,num_msg)
	   #This is to call the live feed to get tweets and mentions by a user's followers
	   #whichever user has subscribers get messages from the live wall, giving them the posts if they have done so
	   liveWall(userId)
    end
	
	
	#Simulate a delete of a user
	def simulateDelete(userId) do 
	     send(getServerEnginePid(),{:deleteTweet,userId})
	end
	
	#Simulate the mention, get a random user to mention about and send the mention message tweet to the server :Engine
    def simulateMention(userId,numofclients) do
        num = 1..numofclients
		useridlist = Enum.to_list(num)
		userToMentionabout = Enum.random(useridlist)
        #userToMentionabout = :rand.uniform(String.to_integer(userId))
		mentionMessage = "MentionTag - user#{userId} tweets bestuser @#{userToMentionabout}"
        send(getServerEnginePid(),{:tweet,mentionMessage,userId})
    end

    #Simulate a hashtag tweet to be sent to the server engine process
    def simulateHashTag(userId) do
	    hashtagMessage = "HashTag - user#{userId} tweets #DOS_project4"
        send(getServerEnginePid(),{:tweet,hashtagMessage,userId})
    end

    #Simulate a normal tweet message to be sent to the server engine for entry in the ets db
    def simulateNormalTweet(userId,num_msg) do
        for _ <- 1..num_msg do
		  tweetMessage = "user#{userId} tweets random #{getRandomTweetString(4)}"
         send(getServerEnginePid(),{:tweet,tweetMessage,userId})
        end
    end	
	
	#Simulate addition of subscriber based on subscriber count and send it to the server engine
	def simulateSubscriberAdd(userId,subscribeCnt,numofclients) do
	   if subscribeCnt > 0 do
	    subscriberSet = getSubscribers(1,subscribeCnt,[])
		IO.puts("Total Number of users- #{numofclients}") 
		IO.puts("The subscribers for user #{inspect userId} are #{inspect subscriberSet}")
		Enum.each subscriberSet, fn subid -> 
        send(getServerEnginePid(),{:subscriber_insert,userId,Integer.to_string(subid)})
        end    
      end	
	end
	
	#This is a function for test purposes, for adding subscribers
	def test_SubscriberSetAddition(userId,subscriberSet) do
	IO.puts("The subscribers for user #{inspect userId} are #{inspect subscriberSet}") 
	    Enum.each subscriberSet, fn subid -> 
        send(getServerEnginePid(),{:subscriber_insert,userId,Integer.to_string(subid)})
        end    
	end
	
	#Simulate retweet, by finding subscriber list from the server , getting their tweet and retweeting
	#their first message as a RETWEET message and sending it back to the server to store in the tweets table.
	def simulateRetweet(userId) do
        send(getServerEnginePid(),{:subscribedTo_tweets,userId})
		#Receive subscriber tweet list
        existinglist = receive do {:retweetList,existinglist} -> existinglist end
        #select first tweet		
        if existinglist != [] do retweet = hd(existinglist)  
         #send the retweets to be added into the tweetsTable
         retweetMessage	= retweet <> " - this is a RETWEET"	 
         send(getServerEnginePid(),{:tweet,retweetMessage,userId})
        end
    end
	
	#This function simulates the the query or search for tweets and reports the performance time
	def queryAndPerformance(userId,timeForTweets,num_msg) do
	    #Query for subscribed to tweets
		
		searchSubscribedToTweets(userId)
        
        #query for the hastag #DOS_project4
        
		searchHashTags("#DOS_project4",userId)
       
        #Query for mention tags
        
		searchMentions(userId)
        
        #Query user tweet set
        
        getUserTweetSet(userId)
         
        timeForTweets = timeForTweets/(num_msg+3)
		#Send the time stats to the main Twitter process to show in console
		sendForStats(timeForTweets)
	end
	
	#Utility function to randomize string
    def getRandomTweetString(length) do
      :crypto.strong_rand_bytes(length) |> Base.url_encode64 |> binary_part(0, length)
    end
	
	#Utility method to get global id of main process to send time for perf stats
	def getTwitterMainPid() do
	   :global.whereis_name(:twitterMain)
	end

    #Getting subscriber list based on the rounded off max subscriber count from the main file 
    def getSubscribers(userc,subscribeCnt,subscribers) do
        if(userc == subscribeCnt) do [userc | subscribers]
        else
        getSubscribers(userc+1,subscribeCnt,[userc | subscribers]) 
        end
    end

    #Test function to get subscribers from server for user
	def getListOfSubsForUser(userId) do
	     send(getServerEnginePid(),{:getSubscriberForUser,userId})
	     receive do
         {:sendSubscribers,slist} ->  IO.puts("Subscribers of User #{userId} are Users #{inspect(slist)} \n")
        end
	end
	
	#Test Functionality to get subscribed to tweets
	def test_getSubTweets(userId) do
	   send(getServerEnginePid(),{:getSubscriberForUser,userId})
	   receive do
	    {:sendSubscribers,subscriberSet} ->
	    Enum.each subscriberSet, fn subid -> 
         getUserTweetSet(subid)
        end 
	   end
	end
	

    #Getting tweets of a user subscribed to from the server engine.
    def searchSubscribedToTweets(userId) do
        send(getServerEnginePid(),{:subscribedTo_tweets,userId})
        receive do
        {:retweetList,rtlist} ->  if rtlist != [], do: IO.puts("Subscribed by tweets of #{userId} are #{inspect(rtlist)} \n")
        end
    end
	
	#Live feed of the User, tweets of its subscribers or mentions, will list the tweets as they are posted
	def liveWall(userId) do
        receive do {:livetweets,tweet_Message} -> IO.puts("Twitter User LIVE Wall: User #{userId}- #{inspect(tweet_Message)} \n") end
        liveWall(userId)
    end
	
	#For Test function - Live feed of the User, tweets of its subscribers or mentions, will list the tweets are they are posted
	def test_liveWall(userId) do
        receive do {:livetweets,tweet_Message} -> IO.puts("Twitter User LIVE Wall: User #{userId}- #{inspect(tweet_Message)} \n") end
    end
	
	
	#Query function to query for a particular hashtag, send request to the server and receive it from the server
	def searchHashTags(hashtag,userId) do
	  send(getServerEnginePid(),{:queryHashtag,hashtag,userId})
      receive do {:get_hashTags,hashtagsList} -> IO.puts("Query Result: Tweets with #{hashtag} of User #{userId} are #{inspect(hashtagsList)} \n")
      end
	end

    #Query function to query for a particular mention, send request to the server and receive it from the server
    def searchMentions(userId) do
      send(getServerEnginePid(),{:queryMentions,userId})
      receive do {:get_Mentions,mentionsList} -> 
	  IO.puts("Query Result: Tweets with @mention of User #{userId} are #{inspect(mentionsList)} \n")
      end	
	end

    #Get all tweets of a particular twitter user from the server engine
    def getUserTweetSet(userId) do
        send(getServerEnginePid(),{:userTweetGet,userId})
        receive do
            {:userTweets,tweets} -> 
			IO.puts("List of Tweets of User #{userId} are #{inspect(tweets)} \n")
			{"List of Tweets of User #{userId} are #{inspect(tweets)}"}			
        end
    end
	
	#Test Method for retweet
	def retweet(userId,numclients) do
	    num = 1..numclients
		useridlist = Enum.to_list(num)
		userToRetweet = Enum.random(useridlist)
	    send(:global.whereis_name(:Engine),{:userTweetGet,userToRetweet})
        existinglist = receive do {:userTweets,existinglist} -> existinglist end 
        if existinglist != [] do retweet = hd(existinglist)            
          send(getServerEnginePid(),{:tweet,retweet <> " -This is RETWEETED",userId})
        end  	
	
	end
	
	#Method to send the times for queries to the main process
	def sendForStats(timeForTweets) do	   
	   send(getTwitterMainPid(),{:stats,timeForTweets})	
	end
	
	#Getting pid of the server engine to send and receive messages
	def getServerEnginePid() do
	    globalServerPid = :global.whereis_name(:Engine)	   
	end

end