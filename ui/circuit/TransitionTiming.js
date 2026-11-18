.pragma library
function clamp(x) { return Math.max(0,Math.min(1,x)); }
function smooth(x) { x=clamp(x);return x*x*(3-2*x); }
function start(mode,seconds,fade,delay,legs) {
 return delay+(mode===1?legs*seconds+fade:0);
}
function emissionStart(mode,start,seconds,legs) {return start+(mode===2?legs*seconds:0);}
// A packet is born only at the origin, then traverses every leg without wrapping.
function packets(now,birthStart,birthEnd,interval,seconds,legs) {
 var result=[],first=Math.max(Math.ceil(birthStart/interval),Math.ceil((now-legs*seconds)/interval));
 var last=Math.min(Math.floor(birthEnd/interval),Math.floor(now/interval));
 for(var i=first;i<=last;i++) {var age=(now-i*interval)/seconds;if(age>=0&&age<legs)result.push(age);}
 return result;
}
function front(now,start,seconds,leg,lead) {return clamp((now-start)/seconds-leg+lead);}
function oldOpacity(now,leg,seconds,fade,followTail) {
 return 1-smooth((now-(followTail?(leg+1)*seconds:0))/fade);
}
// Stable identities; birth is relative to generation origin, never a per-leg loop.
// Keep the whole tail alive until it clears the final destination.
function flightRange(now,origin,stop,interval,seconds,legs,tail) {
 if(interval<=0||seconds<=0||legs<=0||now<origin)return {first:0,last:-1};
 var first=Math.max(0,Math.ceil((now-(legs+tail)*seconds-origin)/interval));
 var last=Math.floor((Math.min(now,stop)-origin)/interval+1e-9);
 while(first<=last&&(now-origin-first*interval)/seconds-tail>=legs)first++;
 while(last>=first&&(now-origin-last*interval)/seconds<0)last--;
 return {first:first,last:last};
}
function flights(now,origin,stop,interval,seconds,legs,tail) {
 var range=flightRange(now,origin,stop,interval,seconds,legs,tail),out=[];
 for(var id=range.first;id<=range.last;id++){
  var birth=origin+id*interval,head=(now-birth)/seconds;
  if(head>=0&&head-tail<legs)out.push({id:id,birth:birth,head:head,tail:Math.max(0,head-tail)});
 }
 return out;
}
// Structural teardown only: this clock never changes packet birth or travel.
function teardownProgress(age,delay,duration,style){
 var t=clamp((age-delay)/Math.max(0.01,duration));
 if(style===1)return t*t;
 if(style===2)return t*t*t;
 if(style===3)return (Math.pow(2,5*t)-1)/31;
 return 0;
}
