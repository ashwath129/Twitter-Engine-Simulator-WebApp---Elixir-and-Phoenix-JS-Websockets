// NOTE: The contents of this file will only be executed if
// you uncomment its entry in "assets/js/app.js".

// To use Phoenix channelsList, the first step is to import Socket
// and connect at the socket path in "lib/web/endpoint.ex":
import {Socket} from "phoenix"

//NAME: ASHWATH VENKATARAMAN UFID: 5198-9461
//NAME: SHASEDHARAN SEKARAN  UFID: 8381-0114

var channelsList = []
var socketsList = []
let messageContainer = document.querySelector('#messages')

let channel

let socket = new Socket("/socket", {params: {token: window.userToken}})
socket.connect()
channel = socket.channel("room:lobby", {})

channel.join()
.receive("ok", resp => { console.log("Joined successfully", resp) })
.receive("error", resp => { console.log("Unable to join", resp) })

function register(userName){
    channel.push("register", userName)
    .receive("registered" , resp => console.log("registered", resp))
}


function subscribe(user, subscribersList) {
    channel.push("subscribe", {username: user, usersToSub: subscribersList})
    .receive("subscribed", resp => console.log("subscribed", user))
    console.log({username: user, usersToSub: subscribersList})
}


 function sendTweet(tweetText, username){
   channel.push("addTweet", {tweetText: tweetText,
    username: username})
    console.log({tweetText: tweetText,
        username: username})
 }




let username = document.querySelector('#username')
let subscription = document.querySelector('#subscribe')
let search_user_tweets = document.querySelector('#search_user_tweets')




username.addEventListener("keypress", event => {
  if (event.keyCode === 13){
      register(username.value)
      let messageItem = document.createElement("li");
      let messageSpan = document.createElement("span");
      messageSpan.className="content-word-bold";
      messageSpan.innerText = `${username.value}!`
      messageItem.innerText = `Successfully Registered! Welcome to Tweeter `
      messageItem.appendChild(messageSpan)
      messageContainer.appendChild(messageItem)
      document.getElementById('username').blur();
  }
})


subscription.addEventListener("keypress", event => {
    if (event.keyCode === 13){
        var val = document.getElementById('subscribe').value
        subscribe(val, [username.value])
        let messageItem = document.createElement("li");
        let messageSpan = document.createElement("span");
        messageSpan.className="content-word-bold";
        messageItem.innerText = `${username.value} subscribed to `
        messageSpan.innerText = `${val}.`
        messageItem.appendChild(messageSpan)
        messageContainer.appendChild(messageItem)
        subscribe.value = ""
        document.getElementById('subscribe').blur();
    }
  })


sendtweet.addEventListener("keypress", event => {
    if (event.keyCode === 13){
        sendTweet(sendtweet.value, username.value)
        let messageItem = document.createElement("li");
        let messageSpan = document.createElement("span");
        messageSpan.className="content-word-bold";
        messageItem.innerText = `${username.value} tweeted: `
        messageSpan.innerText = `${sendtweet.value}`
        messageItem.appendChild(messageSpan)
        messageContainer.appendChild(messageItem)
        sendtweet.value = ""
        document.getElementById('sendtweet').blur();
    }
  })



 document.getElementById('search_user_tweets').onclick = function () {

     console.log({username: username.value})
     channel.push("getSubTweet", {username: username.value})

    }


 document.getElementById('get_tweets').onclick = function () {

     console.log({username: username.value})
     channel.push("getTweets", {username: username.value})

    }

 document.getElementById('get_subscribers').onclick = function () {
     console.log({username: username.value})
     channel.push("getSubscribers", {username: username.value})

    }


search_hashtag.addEventListener("keypress", event => {
    if (event.keyCode === 13){
        channel.push("search_hashtag", {username: username.value, hashtagList: [search_hashtag.value]})
        console.log({username: username.value, hashtagList: [search_hashtag.value]})
        search_hashtag.value = ""
        document.getElementById('search_hashtag').blur();
    }
  })


  document.getElementById('search_mentions').onclick = function () {
    channel.push("search_mentions", {username: username.value})
   }


  document.getElementById('clear_screen').onclick = function () {
    messageContainer.innerHTML=""
   }

  channel.on("subscribedtoTweets", payload => {
    console.log(payload.rtlist)
	let messageDiv = document.createElement("div")
    let messageItem = document.createElement("li");
    let messageSpan1 = document.createElement("span");
    messageSpan1.className= "content-word-bold";
    messageItem.innerText = `Subscriber tweets: `
    messageSpan1.innerText = `${payload.rtlist}.`
    messageItem.appendChild(messageSpan1);
	var rt = payload.rtlist
	console.log(rt.length)

	for(var i=0;i<rt.length;i++){
	  let messageButton = document.createElement("i");
    let messageRetweetIcon = document.createElement("IMG");
    messageButton.className="retweet-button";
    messageRetweetIcon.className="retweet-button-icon";
    messageRetweetIcon.src="./images/retweet.png"
	  let msgspan = document.createElement("span");
    let retspan = document.createElement("span");
    retspan.setAttribute("id","retSpan");
    msgspan.className="tweet-msg-pad content-word-bold";
	  msgspan.innerText=rt[i];
	  messageContainer.appendChild(msgspan);
    messageButton.appendChild(messageRetweetIcon);
	  messageContainer.appendChild(messageButton);
    messageContainer.appendChild(retspan);
	  messageButton.addEventListener('click', ()=>{
		  var retweet = msgspan.innerText
        var retvar = document.getElementById('retSpan');
        retvar.innerText="RETWEETED!"
        channel.push("RETWEET", {username: username.value, rttext: retweet})
    })
    messageContainer.appendChild(messageItem);
	}
  })

channel.on("tweetsofUser", payload => {
    let messageItem = document.createElement("li");
    let messageSpan = document.createElement("span");
    messageSpan.className= "content-word-bold";
    messageItem.innerText = `My Previous Tweets: `
    messageSpan.innerText = `${payload.tweets}.`
    messageItem.appendChild(messageSpan)
    messageContainer.appendChild(messageItem)
  })

channel.on("subscriberlist", payload => {
    let messageItem = document.createElement("li");
    let messageSpan = document.createElement("span");
    messageSpan.className= "content-word-bold";
    messageItem.innerText = `Followers List: `
    messageSpan.innerText = `${payload.sublist}.`
    messageItem.appendChild(messageSpan)
    messageContainer.appendChild(messageItem)
  })


channel.on("search_hashtag", payload => {
    let messageItem = document.createElement("li");
    let messageSpan = document.createElement("span");
    messageSpan.className= "content-word-bold";
    messageItem.innerText = `Hashtag Search Results: `
    messageSpan.innerText = `${payload.hashtagsList}.`
    messageItem.appendChild(messageSpan)
    messageContainer.appendChild(messageItem)
  })

channel.on("search_mentions", payload => {
    let messageItem = document.createElement("li");
    let messageSpan = document.createElement("span");
    messageSpan.className= "content-word-bold";
    messageItem.innerText = `My Mentions: `
    messageSpan.innerText = `${payload.mentionsList}.`
    messageItem.appendChild(messageSpan)
    messageContainer.appendChild(messageItem)
  })



export default socketsList
