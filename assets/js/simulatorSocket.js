import {Socket} from "phoenix"

var userCnt
var channelsList = []
var socketsList = []
let simulateCount = 100
let userFollowers = {}
var simulateDone = 0
let uidList = []
let userId


simulateRegister()

function simulateRegister(){
  for (userCnt = 0; userCnt < simulateCount; userCnt++){
    userId = "TwitterUSER"+userCnt
    let socket = new Socket("/socket", {params: {token: window.userToken, userId: userId}})
    uidList[userCnt] = userId
    userFollowers[userId] = []
    socket.connect()
    socketsList[userCnt] = socket
    let channel = socket.channel("room:lobby", {})
    channelsList[userCnt] = channel
    channel.join()
    .receive("ok", resp => { console.log("Joined successfully", resp) })
    .receive("error", resp => { console.log("Unable to join", resp) })
    channel.push("register", userId)
    .receive("registered" , resp => console.log("registered", resp))
  }
  for (let channel of channelsList){
    channel.on("registered", payload => {
      simulateDone++
      if (simulateDone === simulateCount){
		  simulateDifferentTweets()
		  addSubscribers()
		  searchHashtags()
        console.log("Done simulation")
      }
    })
  }
}

function simulateDifferentTweets(){
	var numUsers = uidList.length
   var mention, tweetText,mentionAdd,tweetSimple,hashtag
   
   for (var i = 0; i < numUsers; i++){
	   console.log(i)
     mention = uidList[Math.floor(Math.random()*numUsers)]
	 mentionAdd = "@"+mention
	 tweetSimple = "HEY FROM "+i
	 hashtag = "#DOSFINAL from "+i
     console.log(mentionAdd)
	 console.log(tweetSimple)
	 console.log(hashtag)

     channelsList[i].push("addTweet", {tweetText: mentionAdd,
       username: uidList[i]})
	   channelsList[i].push("addTweet", {tweetText: tweetSimple,
       username: uidList[i]})
	   channelsList[i].push("addTweet", {tweetText: hashtag,
       username: uidList[i]})
   }
	
}

function addSubscribers(){
	var numUsers = uidList.length
	//Randomly adding some subscribers
	var userToSub = [10,23,37,45,53,67,]
    for (var i = 0; i < numUsers; i++){
	for(var j=0; j<userToSub.length; j++)
	   channelsList[i].push("subscribe", {usersToSub: userToSub[i],
       username: uidList[i]})
	}
}

export default socketsList