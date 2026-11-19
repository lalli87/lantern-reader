(function dartProgram(){function copyProperties(a,b){var t=Object.keys(a)
for(var s=0;s<t.length;s++){var r=t[s]
b[r]=a[r]}}function mixinPropertiesHard(a,b){var t=Object.keys(a)
for(var s=0;s<t.length;s++){var r=t[s]
if(!b.hasOwnProperty(r)){b[r]=a[r]}}}function mixinPropertiesEasy(a,b){Object.assign(b,a)}var z=function(){var t=function(){}
t.prototype={p:{}}
var s=new t()
if(!(Object.getPrototypeOf(s)&&Object.getPrototypeOf(s).p===t.prototype.p))return false
try{if(typeof navigator!="undefined"&&typeof navigator.userAgent=="string"&&navigator.userAgent.indexOf("Chrome/")>=0)return true
if(typeof version=="function"&&version.length==0){var r=version()
if(/^\d+\.\d+\.\d+\.\d+$/.test(r))return true}}catch(q){}return false}()
function inherit(a,b){a.prototype.constructor=a
a.prototype["$i"+a.name]=a
if(b!=null){if(z){Object.setPrototypeOf(a.prototype,b.prototype)
return}var t=Object.create(b.prototype)
copyProperties(a.prototype,t)
a.prototype=t}}function inheritMany(a,b){for(var t=0;t<b.length;t++){inherit(b[t],a)}}function mixinEasy(a,b){mixinPropertiesEasy(b.prototype,a.prototype)
a.prototype.constructor=a}function mixinHard(a,b){mixinPropertiesHard(b.prototype,a.prototype)
a.prototype.constructor=a}function lazy(a,b,c,d){var t=a
a[b]=t
a[c]=function(){if(a[b]===t){a[b]=d()}a[c]=function(){return this[b]}
return a[b]}}function lazyFinal(a,b,c,d){var t=a
a[b]=t
a[c]=function(){if(a[b]===t){var s=d()
if(a[b]!==t){A.hv(b)}a[b]=s}var r=a[b]
a[c]=function(){return r}
return r}}function makeConstList(a,b){if(b!=null)A.c(a,b)
a.$flags=7
return a}function convertToFastObject(a){function t(){}t.prototype=a
new t()
return a}function convertAllToFastObject(a){for(var t=0;t<a.length;++t){convertToFastObject(a[t])}}var y=0
function instanceTearOffGetter(a,b){var t=null
return a?function(c){if(t===null)t=A.df(b)
return new t(c,this)}:function(){if(t===null)t=A.df(b)
return new t(this,null)}}function staticTearOffGetter(a){var t=null
return function(){if(t===null)t=A.df(a).prototype
return t}}var x=0
function tearOffParameters(a,b,c,d,e,f,g,h,i,j){if(typeof h=="number"){h+=x}return{co:a,iS:b,iI:c,rC:d,dV:e,cs:f,fs:g,fT:h,aI:i||0,nDA:j}}function installStaticTearOff(a,b,c,d,e,f,g,h){var t=tearOffParameters(a,true,false,c,d,e,f,g,h,false)
var s=staticTearOffGetter(t)
a[b]=s}function installInstanceTearOff(a,b,c,d,e,f,g,h,i,j){c=!!c
var t=tearOffParameters(a,false,c,d,e,f,g,h,i,!!j)
var s=instanceTearOffGetter(c,t)
a[b]=s}function setOrUpdateInterceptorsByTag(a){var t=v.interceptorsByTag
if(!t){v.interceptorsByTag=a
return}copyProperties(a,t)}function setOrUpdateLeafTags(a){var t=v.leafTags
if(!t){v.leafTags=a
return}copyProperties(a,t)}function updateTypes(a){var t=v.types
var s=t.length
t.push.apply(t,a)
return s}function updateHolder(a,b){copyProperties(b,a)
return a}var hunkHelpers=function(){var t=function(a,b,c,d,e){return function(f,g,h,i){return installInstanceTearOff(f,g,a,b,c,d,[h],i,e,false)}},s=function(a,b,c,d){return function(e,f,g,h){return installStaticTearOff(e,f,a,b,c,[g],h,d)}}
return{inherit:inherit,inheritMany:inheritMany,mixin:mixinEasy,mixinHard:mixinHard,installStaticTearOff:installStaticTearOff,installInstanceTearOff:installInstanceTearOff,_instance_0u:t(0,0,null,["$0"],0),_instance_1u:t(0,1,null,["$1"],0),_instance_2u:t(0,2,null,["$2"],0),_instance_0i:t(1,0,null,["$0"],0),_instance_1i:t(1,1,null,["$1"],0),_instance_2i:t(1,2,null,["$2"],0),_static_0:s(0,null,["$0"],0),_static_1:s(1,null,["$1"],0),_static_2:s(2,null,["$2"],0),makeConstList:makeConstList,lazy:lazy,lazyFinal:lazyFinal,updateHolder:updateHolder,convertToFastObject:convertToFastObject,updateTypes:updateTypes,setOrUpdateInterceptorsByTag:setOrUpdateInterceptorsByTag,setOrUpdateLeafTags:setOrUpdateLeafTags}}()
function initializeDeferredHunk(a){x=v.types.length
a(hunkHelpers,v,w,$)}var J={
eQ(a,b){if(a<0||a>4294967295)throw A.b(A.Q(a,0,4294967295,"length",null))
return J.eS(new Array(a),b)},
eR(a,b){if(a<0)throw A.b(A.cZ("Length must be a non-negative integer: "+a))
return A.c(new Array(a),b.h("i<0>"))},
eS(a,b){var t=A.c(a,b.h("i<0>"))
t.$flags=1
return t},
eT(a,b){var t=u.W
return J.eB(t.a(a),t.a(b))},
dx(a){if(a<256)switch(a){case 9:case 10:case 11:case 12:case 13:case 32:case 133:case 160:return!0
default:return!1}switch(a){case 5760:case 8192:case 8193:case 8194:case 8195:case 8196:case 8197:case 8198:case 8199:case 8200:case 8201:case 8202:case 8232:case 8233:case 8239:case 8287:case 12288:case 65279:return!0
default:return!1}},
eU(a,b){var t,s
for(t=a.length;b<t;){s=a.charCodeAt(b)
if(s!==32&&s!==13&&!J.dx(s))break;++b}return b},
dy(a,b){var t,s,r
for(t=a.length;b>0;b=s){s=b-1
if(!(s<t))return A.e(a,s)
r=a.charCodeAt(s)
if(r!==32&&r!==13&&!J.dx(r))break}return b},
am(a){if(typeof a=="number"){if(Math.floor(a)==a)return J.aJ.prototype
return J.bw.prototype}if(typeof a=="string")return J.a1.prototype
if(a==null)return J.aK.prototype
if(typeof a=="boolean")return J.bv.prototype
if(Array.isArray(a))return J.i.prototype
if(typeof a=="function")return J.aM.prototype
if(typeof a=="object"){if(a instanceof A.j){return a}else{return J.au.prototype}}if(!(a instanceof A.j))return J.Z.prototype
return a},
cE(a){if(a==null)return a
if(Array.isArray(a))return J.i.prototype
if(!(a instanceof A.j))return J.Z.prototype
return a},
bV(a){if(typeof a=="string")return J.a1.prototype
if(a==null)return a
if(Array.isArray(a))return J.i.prototype
if(!(a instanceof A.j))return J.Z.prototype
return a},
hd(a){if(typeof a=="number")return J.as.prototype
if(typeof a=="string")return J.a1.prototype
if(a==null)return a
if(!(a instanceof A.j))return J.Z.prototype
return a},
e5(a){if(typeof a=="string")return J.a1.prototype
if(a==null)return a
if(!(a instanceof A.j))return J.Z.prototype
return a},
ab(a,b){if(a==null)return b==null
if(typeof a!="object")return b!=null&&a===b
return J.am(a).C(a,b)},
C(a,b){if(typeof b==="number")if(Array.isArray(a)||typeof a=="string")if(b>>>0===b&&b<a.length)return a[b]
return J.bV(a).D(a,b)},
aD(a,b){return J.cE(a).i(a,b)},
eA(a,b){return J.e5(a).al(a,b)},
cY(a,b){return J.cE(a).U(a,b)},
eB(a,b){return J.hd(a).u(a,b)},
dp(a,b){return J.cE(a).A(a,b)},
G(a){return J.am(a).gq(a)},
eC(a){return J.bV(a).gp(a)},
eD(a){return J.bV(a).gF(a)},
bi(a){return J.cE(a).gn(a)},
H(a){return J.bV(a).gk(a)},
eE(a){return J.am(a).gK(a)},
aE(a){return J.am(a).j(a)},
eF(a){return J.e5(a).v(a)},
bt:function bt(){},
bv:function bv(){},
aK:function aK(){},
au:function au(){},
a2:function a2(){},
c8:function c8(){},
Z:function Z(){},
aM:function aM(){},
i:function i(a){this.$ti=a},
bu:function bu(){},
bZ:function bZ(a){this.$ti=a},
ac:function ac(a,b,c){var _=this
_.a=a
_.b=b
_.c=0
_.d=null
_.$ti=c},
as:function as(){},
aJ:function aJ(){},
bw:function bw(){},
a1:function a1(){}},A={d2:function d2(){},
eI(a,b,c){if(u._.b(a))return new A.b4(a,b.h("@<0>").E(c).h("b4<1,2>"))
return new A.ad(a,b.h("@<0>").E(c).h("ad<1,2>"))},
W(a,b){a=a+b&536870911
a=a+((a&524287)<<10)&536870911
return a^a>>>6},
cb(a){a=a+((a&67108863)<<3)&536870911
a^=a>>>11
return a+((a&16383)<<15)&536870911},
dj(a){var t,s
for(t=$.L.length,s=0;s<t;++s)if(a===$.L[s])return!0
return!1},
f0(a,b,c,d){A.d4(b,"start")
if(c!=null){A.d4(c,"end")
if(b>c)A.cX(A.Q(b,0,c,"start",null))}return new A.b_(a,b,c,d.h("b_<0>"))},
bY(){return new A.bF("No element")},
a7:function a7(){},
aF:function aF(a,b){this.a=a
this.$ti=b},
ad:function ad(a,b){this.a=a
this.$ti=b},
b4:function b4(a,b){this.a=a
this.$ti=b},
b3:function b3(){},
T:function T(a,b){this.a=a
this.$ti=b},
bA:function bA(a){this.a=a},
ca:function ca(){},
k:function k(){},
z:function z(){},
b_:function b_(a,b,c,d){var _=this
_.a=a
_.b=b
_.c=c
_.$ti=d},
J:function J(a,b,c){var _=this
_.a=a
_.b=b
_.c=0
_.d=null
_.$ti=c},
aS:function aS(a,b,c){this.a=a
this.b=b
this.$ti=c},
aT:function aT(a,b,c){var _=this
_.a=null
_.b=a
_.c=b
_.$ti=c},
ah:function ah(a,b,c){this.a=a
this.b=b
this.$ti=c},
A:function A(a,b,c){this.a=a
this.b=b
this.$ti=c},
b2:function b2(a,b,c){this.a=a
this.b=b
this.$ti=c},
bf:function bf(){},
eO(){throw A.b(A.ce("Cannot modify constant Set"))},
eg(a){var t=A.ef(a)
if(t!=null)return t
return"minified:"+a},
r(a){var t
if(typeof a=="string")return a
if(typeof a=="number"){if(a!==0)return""+a}else if(!0===a)return"true"
else if(!1===a)return"false"
else if(a==null)return"null"
t=J.aE(a)
return t},
bC(a){var t,s=$.dE
if(s==null)s=$.dE=Symbol("identityHashCode")
t=a[s]
if(t==null){t=Math.random()*0x3fffffff|0
a[s]=t}return t},
bD(a){var t,s,r,q
if(a instanceof A.j)return A.F(A.bh(a),null)
t=J.am(a)
if(t===B.l||t===B.m||u.cr.b(a)){s=B.j(a)
if(s!=="Object"&&s!=="")return s
r=a.constructor
if(typeof r=="function"){q=r.name
if(typeof q=="string"&&q!=="Object"&&q!=="")return q}}return A.F(A.bh(a),null)},
dF(a){var t,s,r
if(a==null||typeof a=="number"||A.dd(a))return J.aE(a)
if(typeof a=="string")return JSON.stringify(a)
if(a instanceof A.D)return a.j(0)
if(a instanceof A.S)return a.ak(!0)
t=$.ey()
for(s=0;s<1;++s){r=t[s].b_(a)
if(r!=null)return r}return"Instance of '"+A.bD(a)+"'"},
x(a){var t
if(a<=65535)return String.fromCharCode(a)
if(a<=1114111){t=a-65536
return String.fromCharCode((B.d.aj(t,10)|55296)>>>0,t&1023|56320)}throw A.b(A.Q(a,0,1114111,null,null))},
e(a,b){if(a==null)J.H(a)
throw A.b(A.dg(a,b))},
dg(a,b){var t,s="index"
if(!A.e0(b))return new A.a0(!0,b,s,null)
t=J.H(a)
if(b<0||b>=t)return A.d0(b,t,a,s)
return A.dG(b,s)},
h4(a){return new A.a0(!0,a,null,null)},
b(a){return A.w(a,new Error())},
w(a,b){var t
if(a==null)a=new A.b0()
b.dartException=a
t=A.hw
if("defineProperty" in Object){Object.defineProperty(b,"message",{get:t})
b.name=""}else b.toString=t
return b},
hw(){return J.aE(this.dartException)},
cX(a,b){throw A.w(a,b==null?new Error():b)},
ap(a,b,c){var t
if(b==null)b=0
if(c==null)c=0
t=Error()
A.cX(A.fx(a,b,c),t)},
fx(a,b,c){var t,s,r,q,p,o,n,m,l
if(typeof b=="string")t=b
else{s="[]=;add;removeWhere;retainWhere;removeRange;setRange;setInt8;setInt16;setInt32;setUint8;setUint16;setUint32;setFloat32;setFloat64".split(";")
r=s.length
q=b
if(q>r){c=q/r|0
q%=r}t=s[q]}p=typeof c=="string"?c:"modify;remove from;add to".split(";")[c]
o=u.j.b(a)?"list":"ByteData"
n=a.$flags|0
m="a "
if((n&4)!==0)l="constant "
else if((n&2)!==0){l="unmodifiable "
m="an "}else l=(n&1)!==0?"fixed-length ":""
return new A.b1("'"+t+"': Cannot "+p+" "+m+l+o)},
l(a){throw A.b(A.M(a))},
Y(a){var t,s,r,q,p,o
a=A.ed(a.replace(String({}),"$receiver$"))
t=a.match(/\\\$[a-zA-Z]+\\\$/g)
if(t==null)t=A.c([],u.s)
s=t.indexOf("\\$arguments\\$")
r=t.indexOf("\\$argumentsExpr\\$")
q=t.indexOf("\\$expr\\$")
p=t.indexOf("\\$method\\$")
o=t.indexOf("\\$receiver\\$")
return new A.cc(a.replace(new RegExp("\\\\\\$arguments\\\\\\$","g"),"((?:x|[^x])*)").replace(new RegExp("\\\\\\$argumentsExpr\\\\\\$","g"),"((?:x|[^x])*)").replace(new RegExp("\\\\\\$expr\\\\\\$","g"),"((?:x|[^x])*)").replace(new RegExp("\\\\\\$method\\\\\\$","g"),"((?:x|[^x])*)").replace(new RegExp("\\\\\\$receiver\\\\\\$","g"),"((?:x|[^x])*)"),s,r,q,p,o)},
cd(a){return function($expr$){var $argumentsExpr$="$arguments$"
try{$expr$.$method$($argumentsExpr$)}catch(t){return t.message}}(a)},
dJ(a){return function($expr$){try{$expr$.$method$}catch(t){return t.message}}(a)},
d3(a,b){var t=b==null,s=t?null:b.method
return new A.bx(a,s,t?null:b.receiver)},
dk(a){if(a==null)return new A.c6(a)
if(typeof a!=="object")return a
if("dartException" in a)return A.ao(a,a.dartException)
return A.h2(a)},
ao(a,b){if(u.C.b(b))if(b.$thrownJsError==null)b.$thrownJsError=a
return b},
h2(a){var t,s,r,q,p,o,n,m,l,k,j,i,h
if(!("message" in a))return a
t=a.message
if("number" in a&&typeof a.number=="number"){s=a.number
r=s&65535
if((B.d.aj(s,16)&8191)===10)switch(r){case 438:return A.ao(a,A.d3(A.r(t)+" (Error "+r+")",null))
case 445:case 5007:A.r(t)
return A.ao(a,new A.aV())}}if(a instanceof TypeError){q=$.ei()
p=$.ej()
o=$.ek()
n=$.el()
m=$.eo()
l=$.ep()
k=$.en()
$.em()
j=$.er()
i=$.eq()
h=q.B(t)
if(h!=null)return A.ao(a,A.d3(A.K(t),h))
else{h=p.B(t)
if(h!=null){h.method="call"
return A.ao(a,A.d3(A.K(t),h))}else if(o.B(t)!=null||n.B(t)!=null||m.B(t)!=null||l.B(t)!=null||k.B(t)!=null||n.B(t)!=null||j.B(t)!=null||i.B(t)!=null){A.K(t)
return A.ao(a,new A.aV())}}return A.ao(a,new A.bJ(typeof t=="string"?t:""))}if(a instanceof RangeError){if(typeof t=="string"&&t.indexOf("call stack")!==-1)return new A.aZ()
t=function(b){try{return String(b)}catch(g){}return null}(a)
return A.ao(a,new A.a0(!1,null,null,typeof t=="string"?t.replace(/^RangeError:\s*/,""):t))}if(typeof InternalError=="function"&&a instanceof InternalError)if(typeof t=="string"&&t==="too much recursion")return new A.aZ()
return a},
eb(a){if(a==null)return J.G(a)
if(typeof a=="object")return A.bC(a)
return J.G(a)},
hc(a,b){var t,s,r,q=a.length
for(t=0;t<q;t=r){s=t+1
r=s+1
b.t(0,a[t],a[s])}return b},
fI(a,b,c,d,e,f){u.Z.a(a)
switch(A.ak(b)){case 0:return a.$0()
case 1:return a.$1(c)
case 2:return a.$2(c,d)
case 3:return a.$3(c,d,e)
case 4:return a.$4(c,d,e,f)}throw A.b(new A.cf("Unsupported number of arguments for wrapped closure"))},
h7(a,b){var t=a.$identity
if(!!t)return t
t=A.h8(a,b)
a.$identity=t
return t},
h8(a,b){var t
switch(b){case 0:t=a.$0
break
case 1:t=a.$1
break
case 2:t=a.$2
break
case 3:t=a.$3
break
case 4:t=a.$4
break
default:t=null}if(t!=null)return t.bind(a)
return function(c,d,e){return function(f,g,h,i){return e(c,d,f,g,h,i)}}(a,b,A.fI)},
eN(a1){var t,s,r,q,p,o,n,m,l,k,j=a1.co,i=a1.iS,h=a1.iI,g=a1.nDA,f=a1.aI,e=a1.fs,d=a1.cs,c=e[0],b=d[0],a=j[c],a0=a1.fT
a0.toString
t=i?Object.create(new A.bG().constructor.prototype):Object.create(new A.aq(null,null).constructor.prototype)
t.$initialize=t.constructor
s=i?function static_tear_off(){this.$initialize()}:function tear_off(a2,a3){this.$initialize(a2,a3)}
t.constructor=s
s.prototype=t
t.$_name=c
t.$_target=a
r=!i
if(r)q=A.du(c,a,h,g)
else{t.$static_name=c
q=a}t.$S=A.eJ(a0,i,h)
t[b]=q
for(p=q,o=1;o<e.length;++o){n=e[o]
if(typeof n=="string"){m=j[n]
l=n
n=m}else l=""
k=d[o]
if(k!=null){if(r)n=A.du(l,n,h,g)
t[k]=n}if(o===f)p=n}t.$C=p
t.$R=a1.rC
t.$D=a1.dV
return s},
eJ(a,b,c){if(typeof a=="number")return a
if(typeof a=="string"){if(b)throw A.b("Cannot compute signature for static tearoff.")
return function(d,e){return function(){return e(this,d)}}(a,A.eG)}throw A.b("Error in functionType of tearoff")},
eK(a,b,c,d){var t=A.dt
switch(b?-1:a){case 0:return function(e,f){return function(){return f(this)[e]()}}(c,t)
case 1:return function(e,f){return function(g){return f(this)[e](g)}}(c,t)
case 2:return function(e,f){return function(g,h){return f(this)[e](g,h)}}(c,t)
case 3:return function(e,f){return function(g,h,i){return f(this)[e](g,h,i)}}(c,t)
case 4:return function(e,f){return function(g,h,i,j){return f(this)[e](g,h,i,j)}}(c,t)
case 5:return function(e,f){return function(g,h,i,j,k){return f(this)[e](g,h,i,j,k)}}(c,t)
default:return function(e,f){return function(){return e.apply(f(this),arguments)}}(d,t)}},
du(a,b,c,d){if(c)return A.eM(a,b,d)
return A.eK(b.length,d,a,b)},
eL(a,b,c,d){var t=A.dt,s=A.eH
switch(b?-1:a){case 0:throw A.b(new A.bE("Intercepted function with no arguments."))
case 1:return function(e,f,g){return function(){return f(this)[e](g(this))}}(c,s,t)
case 2:return function(e,f,g){return function(h){return f(this)[e](g(this),h)}}(c,s,t)
case 3:return function(e,f,g){return function(h,i){return f(this)[e](g(this),h,i)}}(c,s,t)
case 4:return function(e,f,g){return function(h,i,j){return f(this)[e](g(this),h,i,j)}}(c,s,t)
case 5:return function(e,f,g){return function(h,i,j,k){return f(this)[e](g(this),h,i,j,k)}}(c,s,t)
case 6:return function(e,f,g){return function(h,i,j,k,l){return f(this)[e](g(this),h,i,j,k,l)}}(c,s,t)
default:return function(e,f,g){return function(){var r=[g(this)]
Array.prototype.push.apply(r,arguments)
return e.apply(f(this),r)}}(d,s,t)}},
eM(a,b,c){var t,s
if($.dr==null)$.dr=A.dq("interceptor")
if($.ds==null)$.ds=A.dq("receiver")
t=b.length
s=A.eL(t,c,a,b)
return s},
df(a){return A.eN(a)},
eG(a,b){return A.be(v.typeUniverse,A.bh(a.a),b)},
dt(a){return a.a},
eH(a){return a.b},
dq(a){var t,s,r,q=new A.aq("receiver","interceptor"),p=Object.getOwnPropertyNames(q)
p.$flags=1
t=p
for(p=t.length,s=0;s<p;++s){r=t[s]
if(q[r]===a)return r}throw A.b(A.cZ("Field name "+a+" not found."))},
e6(a){return v.getIsolateTag(a)},
fb(a,b){var t,s
for(t=0;t<a.length;++t){s=a[t]
if(!(t<b.length))return A.e(b,t)
if(!J.ab(s,b[t]))return!1}return!0},
ha(a,b){var t=b.length,s=v.rttc[""+t+";"+a]
if(s==null)return null
if(t===0)return s
if(t===s.length)return s.apply(null,b)
return s(b)},
dz(a,b,c,d,e,f){var t=b?"m":"",s=c?"":"i",r=d?"u":"",q=e?"s":"",p=function(g,h){try{return new RegExp(g,h)}catch(o){return o}}(a,t+s+r+q+f)
if(p instanceof RegExp)return p
throw A.b(A.dv("Illegal RegExp pattern ("+String(p)+")",a))},
hq(a,b,c){var t=a.indexOf(b,c)
return t>=0},
dh(a){if(a.indexOf("$",0)>=0)return a.replace(/\$/g,"$$$$")
return a},
ht(a,b,c,d){var t=b.af(a,d)
if(t==null)return a
return A.hu(a,t.b.index,t.gV(),c)},
ed(a){if(/[[\]{}()*+?.\\^$|]/.test(a))return a.replace(/[[\]{}()*+?.\\^$|]/g,"\\$&")
return a},
aC(a,b,c){var t
if(typeof b=="string")return A.hs(a,b,c)
if(b instanceof A.aL){t=b.gah()
t.lastIndex=0
return a.replace(t,A.dh(c))}return A.hr(a,b,c)},
hr(a,b,c){var t,s,r,q
for(t=J.eA(b,a),t=t.gn(t),s=0,r="";t.l();){q=t.gm()
r=r+a.substring(s,q.gac())+c
s=q.gV()}t=r+a.substring(s)
return t.charCodeAt(0)==0?t:t},
hs(a,b,c){var t,s,r
if(b===""){if(a==="")return c
t=a.length
for(s=c,r=0;r<t;++r)s=s+a[r]+c
return s.charCodeAt(0)==0?s:s}if(a.indexOf(b,0)<0)return a
if(a.length<500||c.indexOf("$",0)>=0)return a.split(b).join(c)
return a.replace(new RegExp(A.ed(b),"g"),A.dh(c))},
ee(a,b,c,d){return d===0?a.replace(b.b,A.dh(c)):A.ht(a,b,c,d)},
hu(a,b,c,d){return a.substring(0,b)+d+a.substring(c)},
a8:function a8(a,b){this.a=a
this.b=b},
b8:function b8(a,b,c){this.a=a
this.b=b
this.c=c},
b9:function b9(a){this.a=a},
b5:function b5(a,b,c){var _=this
_.a=a
_.b=b
_.c=0
_.d=null
_.$ti=c},
aG:function aG(){},
aH:function aH(a,b,c){this.a=a
this.b=b
this.$ti=c},
bs:function bs(){},
ar:function ar(a,b){this.a=a
this.$ti=b},
aY:function aY(){},
cc:function cc(a,b,c,d,e,f){var _=this
_.a=a
_.b=b
_.c=c
_.d=d
_.e=e
_.f=f},
aV:function aV(){},
bx:function bx(a,b,c){this.a=a
this.b=b
this.c=c},
bJ:function bJ(a){this.a=a},
c6:function c6(a){this.a=a},
D:function D(){},
bl:function bl(){},
bm:function bm(){},
bI:function bI(){},
bG:function bG(){},
aq:function aq(a,b){this.a=a
this.b=b},
bE:function bE(a){this.a=a},
ae:function ae(a){var _=this
_.a=0
_.f=_.e=_.d=_.c=_.b=null
_.r=0
_.$ti=a},
c2:function c2(a,b){this.a=a
this.b=b
this.c=null},
af:function af(a,b){this.a=a
this.$ti=b},
aQ:function aQ(a,b,c,d){var _=this
_.a=a
_.b=b
_.c=c
_.d=null
_.$ti=d},
aO:function aO(a,b){this.a=a
this.$ti=b},
aP:function aP(a,b,c,d){var _=this
_.a=a
_.b=b
_.c=c
_.d=null
_.$ti=d},
S:function S(){},
aw:function aw(){},
ax:function ax(){},
ay:function ay(){},
aL:function aL(a,b){var _=this
_.a=a
_.b=b
_.e=_.c=null},
b7:function b7(a){this.b=a},
bK:function bK(a,b,c){this.a=a
this.b=b
this.c=c},
bL:function bL(a,b,c){var _=this
_.a=a
_.b=b
_.c=c
_.d=null},
bH:function bH(a,b){this.a=a
this.c=b},
bR:function bR(a,b,c){this.a=a
this.b=b
this.c=c},
bS:function bS(a,b,c){var _=this
_.a=a
_.b=b
_.c=c
_.d=null},
d5(a,b){var t=b.c
return t==null?b.c=A.bc(a,"dw",[b.x]):t},
dH(a){var t=a.w
if(t===6||t===7)return A.dH(a.x)
return t===11||t===12},
eZ(a){return a.as},
hm(a,b){var t,s=b.length
for(t=0;t<s;++t)if(!a[t].b(b[t]))return!1
return!0},
bU(a){return A.cl(v.typeUniverse,a,!1)},
hh(a,b){var t,s,r,q,p
if(a==null)return null
t=b.y
s=a.Q
if(s==null)s=a.Q=new Map()
r=b.as
q=s.get(r)
if(q!=null)return q
p=A.aa(v.typeUniverse,a.x,t,0)
s.set(r,p)
return p},
aa(a0,a1,a2,a3){var t,s,r,q,p,o,n,m,l,k,j,i,h,g,f,e,d,c,b,a=a1.w
switch(a){case 5:case 1:case 2:case 3:case 4:return a1
case 6:t=a1.x
s=A.aa(a0,t,a2,a3)
if(s===t)return a1
return A.dQ(a0,s,!0)
case 7:t=a1.x
s=A.aa(a0,t,a2,a3)
if(s===t)return a1
return A.dP(a0,s,!0)
case 8:r=a1.y
q=A.aA(a0,r,a2,a3)
if(q===r)return a1
return A.bc(a0,a1.x,q)
case 9:p=a1.x
o=A.aa(a0,p,a2,a3)
n=a1.y
m=A.aA(a0,n,a2,a3)
if(o===p&&m===n)return a1
return A.d7(a0,o,m)
case 10:l=a1.x
k=a1.y
j=A.aA(a0,k,a2,a3)
if(j===k)return a1
return A.dR(a0,l,j)
case 11:i=a1.x
h=A.aa(a0,i,a2,a3)
g=a1.y
f=A.h_(a0,g,a2,a3)
if(h===i&&f===g)return a1
return A.dO(a0,h,f)
case 12:e=a1.y
a3+=e.length
d=A.aA(a0,e,a2,a3)
p=a1.x
o=A.aa(a0,p,a2,a3)
if(d===e&&o===p)return a1
return A.d8(a0,o,d,!0)
case 13:c=a1.x
if(c<a3)return a1
b=a2[c-a3]
if(b==null)return a1
return b
default:throw A.b(A.bk("Attempted to substitute unexpected RTI kind "+a))}},
aA(a,b,c,d){var t,s,r,q,p=b.length,o=A.cm(p)
for(t=!1,s=0;s<p;++s){r=b[s]
q=A.aa(a,r,c,d)
if(q!==r)t=!0
o[s]=q}return t?o:b},
h0(a,b,c,d){var t,s,r,q,p,o,n=b.length,m=A.cm(n)
for(t=!1,s=0;s<n;s+=3){r=b[s]
q=b[s+1]
p=b[s+2]
o=A.aa(a,p,c,d)
if(o!==p)t=!0
m.splice(s,3,r,q,o)}return t?m:b},
h_(a,b,c,d){var t,s=b.a,r=A.aA(a,s,c,d),q=b.b,p=A.aA(a,q,c,d),o=b.c,n=A.h0(a,o,c,d)
if(r===s&&p===q&&n===o)return b
t=new A.bN()
t.a=r
t.b=p
t.c=n
return t},
c(a,b){a[v.arrayRti]=b
return a},
cD(a){var t=a.$S
if(t!=null){if(typeof t=="number")return A.hf(t)
return a.$S()}return null},
hg(a,b){var t
if(A.dH(b))if(a instanceof A.D){t=A.cD(a)
if(t!=null)return t}return A.bh(a)},
bh(a){if(a instanceof A.j)return A.E(a)
if(Array.isArray(a))return A.u(a)
return A.dc(J.am(a))},
u(a){var t=a[v.arrayRti],s=u.b
if(t==null)return s
if(t.constructor!==s.constructor)return s
return t},
E(a){var t=a.$ti
return t!=null?t:A.dc(a)},
dc(a){var t=a.constructor,s=t.$ccache
if(s!=null)return s
return A.fG(a,t)},
fG(a,b){var t=a instanceof A.D?Object.getPrototypeOf(Object.getPrototypeOf(a)).constructor:b,s=A.fk(v.typeUniverse,t.name)
b.$ccache=s
return s},
hf(a){var t,s=v.types,r=s[a]
if(typeof r=="string"){t=A.cl(v.typeUniverse,r,!1)
s[a]=t
return t}return r},
he(a){return A.a_(A.E(a))},
di(a){var t=A.cD(a)
return A.a_(t==null?A.bh(a):t)},
de(a){var t
if(a instanceof A.S)return A.hb(a.$r,a.S())
t=a instanceof A.D?A.cD(a):null
if(t!=null)return t
if(u.bW.b(a))return J.eE(a).a
if(Array.isArray(a))return A.u(a)
return A.bh(a)},
a_(a){var t=a.r
return t==null?a.r=new A.ck(a):t},
hb(a,b){var t,s,r=b,q=r.length
if(q===0)return u.F
if(0>=q)return A.e(r,0)
t=A.be(v.typeUniverse,A.de(r[0]),"@<0>")
for(s=1;s<q;++s){if(!(s<r.length))return A.e(r,s)
t=A.dT(v.typeUniverse,t,A.de(r[s]))}return A.be(v.typeUniverse,t,a)},
hx(a){return A.a_(A.cl(v.typeUniverse,a,!1))},
fF(a){var t=this
t.b=A.fZ(t)
return t.b(a)},
fZ(a){var t,s,r,q,p
if(a===u.K)return A.fO
if(A.an(a))return A.fS
t=a.w
if(t===6)return A.fC
if(t===1)return A.e2
if(t===7)return A.fJ
s=A.fX(a)
if(s!=null)return s
if(t===8){r=a.x
if(a.y.every(A.an)){a.f="$i"+r
if(r==="o")return A.fM
if(a===u.m)return A.fL
return A.fR}}else if(t===10){q=A.ha(a.x,a.y)
p=q==null?A.e2:q
return p==null?A.da(p):p}return A.fA},
fX(a){if(a.w===8){if(a===u.S)return A.e0
if(a===u.i||a===u.H)return A.fN
if(a===u.N)return A.fQ
if(a===u.y)return A.dd}return null},
fE(a){var t=this,s=A.fz
if(A.an(t))s=A.ft
else if(t===u.K)s=A.da
else if(A.aB(t)){s=A.fB
if(t===u.a3)s=A.fq
else if(t===u.aD)s=A.db
else if(t===u.cG)s=A.fo
else if(t===u.ae)s=A.dW
else if(t===u.I)s=A.fp
else if(t===u.z)s=A.fs}else if(t===u.S)s=A.ak
else if(t===u.N)s=A.K
else if(t===u.y)s=A.fn
else if(t===u.H)s=A.bT
else if(t===u.i)s=A.d9
else if(t===u.m)s=A.fr
t.a=s
return t.a(a)},
fA(a){var t=this
if(a==null)return A.aB(t)
return A.e8(v.typeUniverse,A.hg(a,t),t)},
fC(a){if(a==null)return!0
return this.x.b(a)},
fR(a){var t,s=this
if(a==null)return A.aB(s)
t=s.f
if(a instanceof A.j)return!!a[t]
return!!J.am(a)[t]},
fM(a){var t,s=this
if(a==null)return A.aB(s)
if(typeof a!="object")return!1
if(Array.isArray(a))return!0
t=s.f
if(a instanceof A.j)return!!a[t]
return!!J.am(a)[t]},
fL(a){var t=this
if(a==null)return!1
if(typeof a=="object"){if(a instanceof A.j)return!!a[t.f]
return!0}if(typeof a=="function")return!0
return!1},
e1(a){if(typeof a=="object"){if(a instanceof A.j)return u.m.b(a)
return!0}if(typeof a=="function")return!0
return!1},
fz(a){var t=this
if(a==null){if(A.aB(t))return a}else if(t.b(a))return a
throw A.w(A.dX(a,t),new Error())},
fB(a){var t=this
if(a==null||t.b(a))return a
throw A.w(A.dX(a,t),new Error())},
dX(a,b){return new A.az("TypeError: "+A.dK(a,A.F(b,null)))},
h6(a,b,c,d){if(A.e8(v.typeUniverse,a,b))return a
throw A.w(A.fc("The type argument '"+A.F(a,null)+"' is not a subtype of the type variable bound '"+A.F(b,null)+"' of type variable '"+c+"' in '"+d+"'."),new Error())},
dK(a,b){return A.bq(a)+": type '"+A.F(A.de(a),null)+"' is not a subtype of type '"+b+"'"},
fc(a){return new A.az("TypeError: "+a)},
P(a,b){return new A.az("TypeError: "+A.dK(a,b))},
fJ(a){var t=this
return t.x.b(a)||A.d5(v.typeUniverse,t).b(a)},
fO(a){return a!=null},
da(a){if(a!=null)return a
throw A.w(A.P(a,"Object"),new Error())},
fS(a){return!0},
ft(a){return a},
e2(a){return!1},
dd(a){return!0===a||!1===a},
fn(a){if(!0===a)return!0
if(!1===a)return!1
throw A.w(A.P(a,"bool"),new Error())},
fo(a){if(!0===a)return!0
if(!1===a)return!1
if(a==null)return a
throw A.w(A.P(a,"bool?"),new Error())},
d9(a){if(typeof a=="number")return a
throw A.w(A.P(a,"double"),new Error())},
fp(a){if(typeof a=="number")return a
if(a==null)return a
throw A.w(A.P(a,"double?"),new Error())},
e0(a){return typeof a=="number"&&Math.floor(a)===a},
ak(a){if(typeof a=="number"&&Math.floor(a)===a)return a
throw A.w(A.P(a,"int"),new Error())},
fq(a){if(typeof a=="number"&&Math.floor(a)===a)return a
if(a==null)return a
throw A.w(A.P(a,"int?"),new Error())},
fN(a){return typeof a=="number"},
bT(a){if(typeof a=="number")return a
throw A.w(A.P(a,"num"),new Error())},
dW(a){if(typeof a=="number")return a
if(a==null)return a
throw A.w(A.P(a,"num?"),new Error())},
fQ(a){return typeof a=="string"},
K(a){if(typeof a=="string")return a
throw A.w(A.P(a,"String"),new Error())},
db(a){if(typeof a=="string")return a
if(a==null)return a
throw A.w(A.P(a,"String?"),new Error())},
fr(a){if(A.e1(a))return a
throw A.w(A.P(a,"JSObject"),new Error())},
fs(a){if(a==null)return a
if(A.e1(a))return a
throw A.w(A.P(a,"JSObject?"),new Error())},
e4(a,b){var t,s,r
for(t="",s="",r=0;r<a.length;++r,s=", ")t+=s+A.F(a[r],b)
return t},
fW(a,b){var t,s,r,q,p,o,n=a.x,m=a.y
if(""===n)return"("+A.e4(m,b)+")"
t=m.length
s=n.split(",")
r=s.length-t
for(q="(",p="",o=0;o<t;++o,p=", "){q+=p
if(r===0)q+="{"
q+=A.F(m[o],b)
if(r>=0)q+=" "+s[r];++r}return q+"})"},
dY(a2,a3,a4){var t,s,r,q,p,o,n,m,l,k,j,i,h,g,f,e,d,c,b,a,a0=", ",a1=null
if(a4!=null){t=a4.length
if(a3==null)a3=A.c([],u.s)
else a1=a3.length
s=a3.length
for(r=t;r>0;--r)B.a.i(a3,"T"+(s+r))
for(q=u.O,p="<",o="",r=0;r<t;++r,o=a0){n=a3.length
m=n-1-r
if(!(m>=0))return A.e(a3,m)
p=p+o+a3[m]
l=a4[r]
k=l.w
if(!(k===2||k===3||k===4||k===5||l===q))p+=" extends "+A.F(l,a3)}p+=">"}else p=""
q=a2.x
j=a2.y
i=j.a
h=i.length
g=j.b
f=g.length
e=j.c
d=e.length
c=A.F(q,a3)
for(b="",a="",r=0;r<h;++r,a=a0)b+=a+A.F(i[r],a3)
if(f>0){b+=a+"["
for(a="",r=0;r<f;++r,a=a0)b+=a+A.F(g[r],a3)
b+="]"}if(d>0){b+=a+"{"
for(a="",r=0;r<d;r+=3,a=a0){b+=a
if(e[r+1])b+="required "
b+=A.F(e[r+2],a3)+" "+e[r]}b+="}"}if(a1!=null){a3.toString
a3.length=a1}return p+"("+b+") => "+c},
F(a,b){var t,s,r,q,p,o,n,m=a.w
if(m===5)return"erased"
if(m===2)return"dynamic"
if(m===3)return"void"
if(m===1)return"Never"
if(m===4)return"any"
if(m===6){t=a.x
s=A.F(t,b)
r=t.w
return(r===11||r===12?"("+s+")":s)+"?"}if(m===7)return"FutureOr<"+A.F(a.x,b)+">"
if(m===8){q=A.h1(a.x)
p=a.y
return p.length>0?q+("<"+A.e4(p,b)+">"):q}if(m===10)return A.fW(a,b)
if(m===11)return A.dY(a,b,null)
if(m===12)return A.dY(a.x,b,a.y)
if(m===13){o=a.x
n=b.length
o=n-1-o
if(!(o>=0&&o<n))return A.e(b,o)
return b[o]}return"?"},
h1(a){var t=A.ef(a)
if(t!=null)return t
return"minified:"+a},
fl(a,b){var t=a.tR[b]
while(typeof t=="string")t=a.tR[t]
return t},
fk(a,b){var t,s,r,q,p,o=a.eT,n=o[b]
if(n==null)return A.cl(a,b,!1)
else if(typeof n=="number"){t=n
s=A.bd(a,5,"#")
r=A.cm(t)
for(q=0;q<t;++q)r[q]=s
p=A.bc(a,b,r)
o[b]=p
return p}else return n},
fj(a,b){return A.dU(a.tR,b)},
fi(a,b){return A.dU(a.eT,b)},
cl(a,b,c){var t,s=a.eC,r=s.get(b)
if(r!=null)return r
t=A.dS(a,null,b,!1)
s.set(b,t)
return t},
be(a,b,c){var t,s,r=b.z
if(r==null)r=b.z=new Map()
t=r.get(c)
if(t!=null)return t
s=A.dS(a,b,c,!0)
r.set(c,s)
return s},
dT(a,b,c){var t,s,r,q=b.Q
if(q==null)q=b.Q=new Map()
t=c.as
s=q.get(t)
if(s!=null)return s
r=A.d7(a,b,c.w===9?c.y:[c])
q.set(t,r)
return r},
dS(a,b,c,d){return A.f9(A.f3(a,b,c,d))},
a9(a,b){b.a=A.fE
b.b=A.fF
return b},
bd(a,b,c){var t,s,r=a.eC.get(c)
if(r!=null)return r
t=new A.R(null,null)
t.w=b
t.as=c
s=A.a9(a,t)
a.eC.set(c,s)
return s},
dQ(a,b,c){var t,s=b.as+"?",r=a.eC.get(s)
if(r!=null)return r
t=A.fg(a,b,s,c)
a.eC.set(s,t)
return t},
fg(a,b,c,d){var t,s,r
if(d){t=b.w
s=!0
if(!A.an(b))if(!(b===u.P||b===u.T))if(t!==6)s=t===7&&A.aB(b.x)
if(s)return b
else if(t===1)return u.P}r=new A.R(null,null)
r.w=6
r.x=b
r.as=c
return A.a9(a,r)},
dP(a,b,c){var t,s=b.as+"/",r=a.eC.get(s)
if(r!=null)return r
t=A.fe(a,b,s,c)
a.eC.set(s,t)
return t},
fe(a,b,c,d){var t,s
if(d){t=b.w
if(A.an(b)||b===u.K)return b
else if(t===1)return A.bc(a,"dw",[b])
else if(b===u.P||b===u.T)return u.bc}s=new A.R(null,null)
s.w=7
s.x=b
s.as=c
return A.a9(a,s)},
fh(a,b){var t,s,r=""+b+"^",q=a.eC.get(r)
if(q!=null)return q
t=new A.R(null,null)
t.w=13
t.x=b
t.as=r
s=A.a9(a,t)
a.eC.set(r,s)
return s},
bb(a){var t,s,r,q=a.length
for(t="",s="",r=0;r<q;++r,s=",")t+=s+a[r].as
return t},
fd(a){var t,s,r,q,p,o=a.length
for(t="",s="",r=0;r<o;r+=3,s=","){q=a[r]
p=a[r+1]?"!":":"
t+=s+q+p+a[r+2].as}return t},
bc(a,b,c){var t,s,r,q=b
if(c.length>0)q+="<"+A.bb(c)+">"
t=a.eC.get(q)
if(t!=null)return t
s=new A.R(null,null)
s.w=8
s.x=b
s.y=c
if(c.length>0)s.c=c[0]
s.as=q
r=A.a9(a,s)
a.eC.set(q,r)
return r},
d7(a,b,c){var t,s,r,q,p,o
if(b.w===9){t=b.x
s=b.y.concat(c)}else{s=c
t=b}r=t.as+(";<"+A.bb(s)+">")
q=a.eC.get(r)
if(q!=null)return q
p=new A.R(null,null)
p.w=9
p.x=t
p.y=s
p.as=r
o=A.a9(a,p)
a.eC.set(r,o)
return o},
dR(a,b,c){var t,s,r="+"+(b+"("+A.bb(c)+")"),q=a.eC.get(r)
if(q!=null)return q
t=new A.R(null,null)
t.w=10
t.x=b
t.y=c
t.as=r
s=A.a9(a,t)
a.eC.set(r,s)
return s},
dO(a,b,c){var t,s,r,q,p,o=b.as,n=c.a,m=n.length,l=c.b,k=l.length,j=c.c,i=j.length,h="("+A.bb(n)
if(k>0){t=m>0?",":""
h+=t+"["+A.bb(l)+"]"}if(i>0){t=m>0?",":""
h+=t+"{"+A.fd(j)+"}"}s=o+(h+")")
r=a.eC.get(s)
if(r!=null)return r
q=new A.R(null,null)
q.w=11
q.x=b
q.y=c
q.as=s
p=A.a9(a,q)
a.eC.set(s,p)
return p},
d8(a,b,c,d){var t,s=b.as+("<"+A.bb(c)+">"),r=a.eC.get(s)
if(r!=null)return r
t=A.ff(a,b,c,s,d)
a.eC.set(s,t)
return t},
ff(a,b,c,d,e){var t,s,r,q,p,o,n,m
if(e){t=c.length
s=A.cm(t)
for(r=0,q=0;q<t;++q){p=c[q]
if(p.w===1){s[q]=p;++r}}if(r>0){o=A.aa(a,b,s,0)
n=A.aA(a,c,s,0)
return A.d8(a,o,n,c!==n)}}m=new A.R(null,null)
m.w=12
m.x=b
m.y=c
m.as=d
return A.a9(a,m)},
f3(a,b,c,d){return{u:a,e:b,r:c,s:[],p:0,n:d}},
f9(a){var t,s,r,q,p,o,n,m=a.r,l=a.s
for(t=m.length,s=0;s<t;){r=m.charCodeAt(s)
if(r>=48&&r<=57)s=A.f5(s+1,r,m,l)
else if((((r|32)>>>0)-97&65535)<26||r===95||r===36||r===124)s=A.dM(a,s,m,l,!1)
else if(r===46)s=A.dM(a,s,m,l,!0)
else{++s
switch(r){case 44:break
case 58:l.push(!1)
break
case 33:l.push(!0)
break
case 59:l.push(A.aj(a.u,a.e,l.pop()))
break
case 94:l.push(A.fh(a.u,l.pop()))
break
case 35:l.push(A.bd(a.u,5,"#"))
break
case 64:l.push(A.bd(a.u,2,"@"))
break
case 126:l.push(A.bd(a.u,3,"~"))
break
case 60:l.push(a.p)
a.p=l.length
break
case 62:A.f7(a,l)
break
case 38:A.f6(a,l)
break
case 63:q=a.u
l.push(A.dQ(q,A.aj(q,a.e,l.pop()),a.n))
break
case 47:q=a.u
l.push(A.dP(q,A.aj(q,a.e,l.pop()),a.n))
break
case 40:l.push(-3)
l.push(a.p)
a.p=l.length
break
case 41:A.f4(a,l)
break
case 91:l.push(a.p)
a.p=l.length
break
case 93:p=l.splice(a.p)
A.dN(a.u,a.e,p)
a.p=l.pop()
l.push(p)
l.push(-1)
break
case 123:l.push(a.p)
a.p=l.length
break
case 125:p=l.splice(a.p)
A.fa(a.u,a.e,p)
a.p=l.pop()
l.push(p)
l.push(-2)
break
case 43:o=m.indexOf("(",s)
l.push(m.substring(s,o))
l.push(-4)
l.push(a.p)
a.p=l.length
s=o+1
break
default:throw"Bad character "+r}}}n=l.pop()
return A.aj(a.u,a.e,n)},
f5(a,b,c,d){var t,s,r=b-48
for(t=c.length;a<t;++a){s=c.charCodeAt(a)
if(!(s>=48&&s<=57))break
r=r*10+(s-48)}d.push(r)
return a},
dM(a,b,c,d,e){var t,s,r,q,p,o,n=b+1
for(t=c.length;n<t;++n){s=c.charCodeAt(n)
if(s===46){if(e)break
e=!0}else{if(!((((s|32)>>>0)-97&65535)<26||s===95||s===36||s===124))r=s>=48&&s<=57
else r=!0
if(!r)break}}q=c.substring(b,n)
if(e){t=a.u
p=a.e
if(p.w===9)p=p.x
o=A.fl(t,p.x)[q]
if(o==null)A.cX('No "'+q+'" in "'+A.eZ(p)+'"')
d.push(A.be(t,p,o))}else d.push(q)
return n},
f7(a,b){var t,s=a.u,r=A.dL(a,b),q=b.pop()
if(typeof q=="string")b.push(A.bc(s,q,r))
else{t=A.aj(s,a.e,q)
switch(t.w){case 11:b.push(A.d8(s,t,r,a.n))
break
default:b.push(A.d7(s,t,r))
break}}},
f4(a,b){var t,s,r,q=a.u,p=b.pop(),o=null,n=null
if(typeof p=="number")switch(p){case-1:o=b.pop()
break
case-2:n=b.pop()
break
default:b.push(p)
break}else b.push(p)
t=A.dL(a,b)
p=b.pop()
switch(p){case-3:p=b.pop()
if(o==null)o=q.sEA
if(n==null)n=q.sEA
s=A.aj(q,a.e,p)
r=new A.bN()
r.a=t
r.b=o
r.c=n
b.push(A.dO(q,s,r))
return
case-4:b.push(A.dR(q,b.pop(),t))
return
default:throw A.b(A.bk("Unexpected state under `()`: "+A.r(p)))}},
f6(a,b){var t=b.pop()
if(0===t){b.push(A.bd(a.u,1,"0&"))
return}if(1===t){b.push(A.bd(a.u,4,"1&"))
return}throw A.b(A.bk("Unexpected extended operation "+A.r(t)))},
dL(a,b){var t=b.splice(a.p)
A.dN(a.u,a.e,t)
a.p=b.pop()
return t},
aj(a,b,c){if(typeof c=="string")return A.bc(a,c,a.sEA)
else if(typeof c=="number"){b.toString
return A.f8(a,b,c)}else return c},
dN(a,b,c){var t,s=c.length
for(t=0;t<s;++t)c[t]=A.aj(a,b,c[t])},
fa(a,b,c){var t,s=c.length
for(t=2;t<s;t+=3)c[t]=A.aj(a,b,c[t])},
f8(a,b,c){var t,s,r=b.w
if(r===9){if(c===0)return b.x
t=b.y
s=t.length
if(c<=s)return t[c-1]
c-=s
b=b.x
r=b.w}else if(c===0)return b
if(r!==8)throw A.b(A.bk("Indexed base must be an interface type"))
t=b.y
if(c<=t.length)return t[c-1]
throw A.b(A.bk("Bad index "+c+" for "+b.j(0)))},
e8(a,b,c){var t,s=b.d
if(s==null)s=b.d=new Map()
t=s.get(c)
if(t==null){t=A.v(a,b,null,c,null)
s.set(c,t)}return t},
v(a,b,c,d,e){var t,s,r,q,p,o,n,m,l,k,j
if(b===d)return!0
if(A.an(d))return!0
t=b.w
if(t===4)return!0
if(A.an(b))return!1
if(b.w===1)return!0
s=t===13
if(s)if(A.v(a,c[b.x],c,d,e))return!0
r=d.w
q=u.P
if(b===q||b===u.T){if(r===7)return A.v(a,b,c,d.x,e)
return d===q||d===u.T||r===6}if(d===u.K){if(t===7)return A.v(a,b.x,c,d,e)
return t!==6}if(t===7){if(!A.v(a,b.x,c,d,e))return!1
return A.v(a,A.d5(a,b),c,d,e)}if(t===6)return A.v(a,q,c,d,e)&&A.v(a,b.x,c,d,e)
if(r===7){if(A.v(a,b,c,d.x,e))return!0
return A.v(a,b,c,A.d5(a,d),e)}if(r===6)return A.v(a,b,c,q,e)||A.v(a,b,c,d.x,e)
if(s)return!1
q=t!==11
if((!q||t===12)&&d===u.Z)return!0
p=t===10
if(p&&d===u.B)return!0
if(r===12){if(b===u.g)return!0
if(t!==12)return!1
o=b.y
n=d.y
m=o.length
if(m!==n.length)return!1
c=c==null?o:o.concat(c)
e=e==null?n:n.concat(e)
for(l=0;l<m;++l){k=o[l]
j=n[l]
if(!A.v(a,k,c,j,e)||!A.v(a,j,e,k,c))return!1}return A.e_(a,b.x,c,d.x,e)}if(r===11){if(b===u.g)return!0
if(q)return!1
return A.e_(a,b,c,d,e)}if(t===8){if(r!==8)return!1
return A.fK(a,b,c,d,e)}if(p&&r===10)return A.fP(a,b,c,d,e)
return!1},
e_(a2,a3,a4,a5,a6){var t,s,r,q,p,o,n,m,l,k,j,i,h,g,f,e,d,c,b,a,a0,a1
if(!A.v(a2,a3.x,a4,a5.x,a6))return!1
t=a3.y
s=a5.y
r=t.a
q=s.a
p=r.length
o=q.length
if(p>o)return!1
n=o-p
m=t.b
l=s.b
k=m.length
j=l.length
if(p+k<o+j)return!1
for(i=0;i<p;++i){h=r[i]
if(!A.v(a2,q[i],a6,h,a4))return!1}for(i=0;i<n;++i){h=m[i]
if(!A.v(a2,q[p+i],a6,h,a4))return!1}for(i=0;i<j;++i){h=m[n+i]
if(!A.v(a2,l[i],a6,h,a4))return!1}g=t.c
f=s.c
e=g.length
d=f.length
for(c=0,b=0;b<d;b+=3){a=f[b]
for(;;){if(c>=e)return!1
a0=g[c]
c+=3
if(a<a0)return!1
a1=g[c-2]
if(a0<a){if(a1)return!1
continue}h=f[b+1]
if(a1&&!h)return!1
h=g[c-1]
if(!A.v(a2,f[b+2],a6,h,a4))return!1
break}}while(c<e){if(g[c+1])return!1
c+=3}return!0},
fK(a,b,c,d,e){var t,s,r,q,p,o=b.x,n=d.x
while(o!==n){t=a.tR[o]
if(t==null)return!1
if(typeof t=="string"){o=t
continue}s=t[n]
if(s==null)return!1
r=s.length
q=r>0?new Array(r):v.typeUniverse.sEA
for(p=0;p<r;++p)q[p]=A.be(a,b,s[p])
return A.dV(a,q,null,c,d.y,e)}return A.dV(a,b.y,null,c,d.y,e)},
dV(a,b,c,d,e,f){var t,s=b.length
for(t=0;t<s;++t)if(!A.v(a,b[t],d,e[t],f))return!1
return!0},
fP(a,b,c,d,e){var t,s=b.y,r=d.y,q=s.length
if(q!==r.length)return!1
if(b.x!==d.x)return!1
for(t=0;t<q;++t)if(!A.v(a,s[t],c,r[t],e))return!1
return!0},
aB(a){var t=a.w,s=!0
if(!(a===u.P||a===u.T))if(!A.an(a))if(t!==6)s=t===7&&A.aB(a.x)
return s},
an(a){var t=a.w
return t===2||t===3||t===4||t===5||a===u.O},
dU(a,b){var t,s,r=Object.keys(b),q=r.length
for(t=0;t<q;++t){s=r[t]
a[s]=b[s]}},
cm(a){return a>0?new Array(a):v.typeUniverse.sEA},
R:function R(a,b){var _=this
_.a=a
_.b=b
_.r=_.f=_.d=_.c=null
_.w=0
_.as=_.Q=_.z=_.y=_.x=null},
bN:function bN(){this.c=this.b=this.a=null},
ck:function ck(a){this.a=a},
bM:function bM(){},
az:function az(a){this.a=a},
c3(a,b,c){return b.h("@<0>").E(c).h("dB<1,2>").a(A.hc(a,new A.ae(b.h("@<0>").E(c).h("ae<1,2>"))))},
eV(a,b){return new A.ae(a.h("@<0>").E(b).h("ae<1,2>"))},
c4(a){return new A.b6(a.h("b6<0>"))},
d6(){var t=Object.create(null)
t["<non-identifier-key>"]=t
delete t["<non-identifier-key>"]
return t},
dD(a){var t,s
if(A.dj(a))return"{...}"
t=new A.a6("")
try{s={}
B.a.i($.L,a)
t.a+="{"
s.a=!0
a.N(0,new A.c5(s,t))
t.a+="}"}finally{if(0>=$.L.length)return A.e($.L,-1)
$.L.pop()}s=t.a
return s.charCodeAt(0)==0?s:s},
b6:function b6(a){var _=this
_.a=0
_.f=_.e=_.d=_.c=_.b=null
_.r=0
_.$ti=a},
bQ:function bQ(a){this.a=a
this.b=null},
ai:function ai(a,b,c){var _=this
_.a=a
_.b=b
_.d=_.c=null
_.$ti=c},
O:function O(){},
I:function I(){},
c5:function c5(a,b){this.a=a
this.b=b},
a5:function a5(){},
ba:function ba(){},
fV(a,b){var t,s,r,q=null
try{q=JSON.parse(a)}catch(s){t=A.dk(s)
r=A.dv(String(t),null)
throw A.b(r)}r=A.cq(q)
return r},
cq(a){var t
if(a==null)return null
if(typeof a!="object")return a
if(!Array.isArray(a))return new A.bO(a,Object.create(null))
for(t=0;t<a.length;++t)a[t]=A.cq(a[t])
return a},
dA(a,b,c){return new A.aN(a,b)},
fw(a){return a.b6()},
f1(a,b){return new A.cg(a,[],A.h9())},
f2(a,b,c){var t,s=new A.a6(""),r=A.f1(s,b)
r.Z(a)
t=s.a
return t.charCodeAt(0)==0?t:t},
bO:function bO(a,b){this.a=a
this.b=b
this.c=null},
bP:function bP(a){this.a=a},
bn:function bn(){},
bp:function bp(){},
aN:function aN(a,b){this.a=a
this.b=b},
by:function by(a,b){this.a=a
this.b=b},
c_:function c_(){},
c1:function c1(a){this.b=a},
c0:function c0(a){this.a=a},
ch:function ch(){},
ci:function ci(a,b){this.a=a
this.b=b},
cg:function cg(a,b,c){this.c=a
this.a=b
this.b=c},
dC(a,b,c,d){var t,s=c?J.eR(a,d):J.eQ(a,d)
if(a!==0&&b!=null)for(t=0;t<s.length;++t)s[t]=b
return s},
eW(a,b,c){var t,s,r=A.c([],c.h("i<0>"))
for(t=a.length,s=0;s<a.length;a.length===t||(0,A.l)(a),++s)B.a.i(r,c.a(a[s]))
r.$flags=1
return r},
ag(a,b){var t,s
if(Array.isArray(a))return A.c(a.slice(0),b.h("i<0>"))
t=A.c([],b.h("i<0>"))
for(s=J.bi(a);s.l();)B.a.i(t,s.gm())
return t},
y(a,b){return new A.aL(a,A.dz(a,!1,b,!1,!1,""))},
dI(a,b,c){var t=J.bi(b)
if(!t.l())return a
if(c.length===0){do a+=A.r(t.gm())
while(t.l())}else{a+=A.r(t.gm())
while(t.l())a=a+c+A.r(t.gm())}return a},
bq(a){if(typeof a=="number"||A.dd(a)||a==null)return J.aE(a)
if(typeof a=="string")return JSON.stringify(a)
return A.dF(a)},
bk(a){return new A.bj(a)},
cZ(a){return new A.a0(!1,null,null,a)},
dG(a,b){return new A.aW(null,null,!0,a,b,"Value not in range")},
Q(a,b,c,d,e){return new A.aW(b,c,!0,a,d,"Invalid value")},
eY(a,b,c){if(0>a||a>c)throw A.b(A.Q(a,0,c,"start",null))
if(b!=null){if(a>b||b>c)throw A.b(A.Q(b,a,c,"end",null))
return b}return c},
d4(a,b){if(a<0)throw A.b(A.Q(a,0,null,b,null))
return a},
d0(a,b,c,d){return new A.br(b,!0,a,d,"Index out of range")},
ce(a){return new A.b1(a)},
M(a){return new A.bo(a)},
dv(a,b){return new A.aI(a,b)},
eP(a,b,c){var t,s
if(A.dj(a)){if(b==="("&&c===")")return"(...)"
return b+"..."+c}t=A.c([],u.s)
B.a.i($.L,a)
try{A.fT(a,t)}finally{if(0>=$.L.length)return A.e($.L,-1)
$.L.pop()}s=A.dI(b,u.a.a(t),", ")+c
return s.charCodeAt(0)==0?s:s},
d1(a,b,c){var t,s
if(A.dj(a))return b+"..."+c
t=new A.a6(b)
B.a.i($.L,a)
try{s=t
s.a=A.dI(s.a,a,", ")}finally{if(0>=$.L.length)return A.e($.L,-1)
$.L.pop()}t.a+=c
s=t.a
return s.charCodeAt(0)==0?s:s},
fT(a,b){var t,s,r,q,p,o,n,m=a.gn(a),l=0,k=0
for(;;){if(!(l<80||k<3))break
if(!m.l())return
t=A.r(m.gm())
B.a.i(b,t)
l+=t.length+2;++k}if(!m.l()){if(k<=5)return
if(0>=b.length)return A.e(b,-1)
s=b.pop()
if(0>=b.length)return A.e(b,-1)
r=b.pop()}else{q=m.gm();++k
if(!m.l()){if(k<=4){B.a.i(b,A.r(q))
return}s=A.r(q)
if(0>=b.length)return A.e(b,-1)
r=b.pop()
l+=s.length+2}else{p=m.gm();++k
for(;m.l();q=p,p=o){o=m.gm();++k
if(k>100){for(;;){if(!(l>75&&k>3))break
if(0>=b.length)return A.e(b,-1)
l-=b.pop().length+2;--k}B.a.i(b,"...")
return}}r=A.r(q)
s=A.r(p)
l+=s.length+r.length+4}}if(k>b.length+2){l+=5
n="..."}else n=null
for(;;){if(!(l>80&&b.length>3))break
if(0>=b.length)return A.e(b,-1)
l-=b.pop().length+2
if(n==null){l+=5
n="..."}}if(n!=null)B.a.i(b,n)
B.a.i(b,r)
B.a.i(b,s)},
c7(a,b,c,d){var t
if(B.e===c){t=J.G(a)
b=J.G(b)
return A.cb(A.W(A.W($.bW(),t),b))}if(B.e===d){t=J.G(a)
b=J.G(b)
c=J.G(c)
return A.cb(A.W(A.W(A.W($.bW(),t),b),c))}t=J.G(a)
b=J.G(b)
c=J.G(c)
d=J.G(d)
d=A.cb(A.W(A.W(A.W(A.W($.bW(),t),b),c),d))
return d},
eX(a){var t,s,r=$.bW()
for(t=a.length,s=0;s<a.length;a.length===t||(0,A.l)(a),++s)r=A.W(r,J.G(a[s]))
return A.cb(r)},
p:function p(){},
bj:function bj(a){this.a=a},
b0:function b0(){},
a0:function a0(a,b,c,d){var _=this
_.a=a
_.b=b
_.c=c
_.d=d},
aW:function aW(a,b,c,d,e,f){var _=this
_.e=a
_.f=b
_.a=c
_.b=d
_.c=e
_.d=f},
br:function br(a,b,c,d,e){var _=this
_.f=a
_.a=b
_.b=c
_.c=d
_.d=e},
b1:function b1(a){this.a=a},
bF:function bF(a){this.a=a},
bo:function bo(a){this.a=a},
aZ:function aZ(){},
cf:function cf(a){this.a=a},
aI:function aI(a,b){this.a=a
this.b=b},
d:function d(){},
a3:function a3(a,b,c){this.a=a
this.b=b
this.$ti=c},
aU:function aU(){},
j:function j(){},
a6:function a6(a){this.a=a},
d_(a,b,c){return new A.bX(c,a)},
hp(a,b,c,d){var t,s,r,q,p,o,n,m,l,k,j,i=null,h=u.s,g=A.c([],h)
for(t=c.length,s=0;s<c.length;c.length===t||(0,A.l)(c),++s){r=c[s]
q=!1
if(r.length<80){p=$.et()
if(p.b.test(r)){q=A.y("\\d|prologue|epilogue|[\u4e00\u4e8c\u4e09\u56db\u4e94\u516d\u4e03\u516b\u4e5d\u5341]",!1)
q=q.b.test(r)}}g.push(q?"# "+r:r)}t=u.Q
q=u.U
o=0
r=1
for(;;){if(!(r<=3&&o===0))break
if(new A.A(g,t.a(new A.cV(r)),q).gk(0)>=2)o=r;++r}n=A.c([],u.p)
if(o===0)B.a.i(n,new A.N(a,g,i))
else for(t=g.length,m=i,s=0;s<g.length;g.length===t||(0,A.l)(g),++s){l=g[s]
k=A.e7(l)
if(k>0&&k<=o){q=$.dm()
m=new A.N(A.ee(l,q,"",0),A.c([],h),i)
B.a.i(n,m)}else{if(m==null){j=new A.N(a,A.c([],h),i)
B.a.i(n,j)
q=j
m=q}else q=m
B.a.i(q.b,l)}}B.a.aW(n,new A.cW(n,a))
return A.d_(n,b,a)},
N:function N(a,b,c){this.a=a
this.b=b
this.c=c},
bX:function bX(a,b){this.a=a
this.w=b},
cV:function cV(a){this.a=a},
cW:function cW(a,b){this.a=a
this.b=b},
ec(a,a0,a1){var t,s,r,q,p,o,n,m,l,k,j,i,h,g,f={},e=B.a.aK(a,new A.cQ()),d=u.s,c=A.c([],d),b=A.c([],u.X)
for(t=0;t<a.length;++t){s=a[t]
s=A.aC(s,"\r\n","\n")
s=A.aC(s,"\r","\n").split("\n")
r=s.length
q=a0+t
p=0
for(;p<r;++p){o=s[p]
if(B.b.J(o,"\u2029"))n=B.b.v(A.aC(o,"\u2029","")).length===0
else n=!1
if(n){B.a.i(c,"\u2029")
B.a.i(b,q)
continue}n=A.y("[\\s\xa0]+",!0)
o=B.b.v(A.aC(o,n," "))
n=A.y("^(page\\s*)?\\d{1,4}(\\s*(of|/)\\s*\\d+)?$",!1)
B.a.i(c,n.b.test(o)?"":o)
B.a.i(b,q)}B.a.i(c,"")
B.a.i(b,q)}s=u.A
m=A.ag(new A.aS(new A.A(c,u.Q.a(new A.cR()),u.U),u.bv.a(new A.cS()),s),s.h("d.E"))
B.a.ab(m)
s=m.length
if(s===0)l=80
else{s=B.d.L(B.c.aQ(s*0.8),0,m.length-1)
if(!(s>=0&&s<m.length))return A.e(m,s)
l=m[s]}k=A.c([],d)
j=new A.a6("")
f.a=a0
i=new A.cT(f,j,k,a1)
for(d=l*0.72,h=0;h<c.length;++h){o=c[h]
if(o==="\u2029"){i.$0()
continue}s=o.length
if(s===0){s=j.a
g=B.b.aZ(s.charCodeAt(0)==0?s:s)
if(g.length!==0){s=$.dn()
s=s.b.test(g)}else s=!1
if(s)i.$0()
continue}if(s<70){r=$.ew()
r=r.b.test(o)}else r=!1
if(r){i.$0()
B.a.i(k,o)
if(!(h<b.length))return A.e(b,h)
B.a.i(a1,b[h])
continue}r=j.a
g=r.charCodeAt(0)==0?r:r
if(B.b.v(g).length===0){if(!(h<b.length))return A.e(b,h)
f.a=b[h]}r=!1
if(B.b.W(g,"-"))if(!B.b.W(g," -")){r=A.y("^[a-z]",!0)
r=r.b.test(o)}if(r){j.a=""
r=B.b.H(g,0,g.length-1)
j.a=r
j.a=r+o}else{if(g.length!==0)j.a+=" "
j.a+=o}if(e)continue
if(s<d){s=$.dn()
s=s.b.test(o)}else s=!1
if(s)i.$0()}i.$0()
return k},
h3(a,b){var t,s,r,q,p,o,n,m,l,k,j,i=u.N,h=A.eV(i,u.S)
for(t=b.length,s=0;s<b.length;b.length===t||(0,A.l)(b),++s){r=b[s]
if(r==null)continue
q=A.c4(i)
for(p=r.a,o=p.length,n=0;n<p.length;p.length===o||(0,A.l)(p),++n)q.i(0,A.ea(p[n],r))
p=q.$ti
o=new A.ai(q,q.r,p.h("ai<1>"))
o.c=q.e
p=p.c
while(o.l()){q=o.d
if(q==null)q=p.a(q)
if(q.length!==0){m=h.D(0,q)
h.t(0,q,(m==null?0:m)+1)}}}t=A.u(b)
l=Math.max(3,B.c.aL(new A.A(b,t.h("n(1)").a(new A.cz()),t.h("A<1>")).gk(0)*0.25))
i=A.c4(i)
for(t=new A.aO(h,h.$ti.h("aO<1,2>")).gn(0);t.l();){k=t.d
if(k.b>=l)i.i(0,k.a)}for(j=0;j<b.length;++j){r=b[j]
if(r!=null&&r.a.length!==0)B.a.t(a,j,A.hj(r,i))}},
h5(a8,a9,b0){var t,s,r,q,p,o,n,m,l,k,j,i,h,g,f,e,d,c,b,a,a0,a1,a2,a3,a4,a5,a6,a7=A.ag(a9,u.x)
if(B.a.aR(a8,0,new A.cA(),u.S)<40*B.d.L(a8.length,1,5))throw A.b(B.k)
t=B.b.aX(b0,A.y("\\.pdf$",!1),"")
B.a.G(a7,new A.cB())
s=new A.cC(a8)
if(a7.length>=2){r=A.c([],u.p)
if(B.a.ga8(a7).b>1){q=s.$3(t,0,B.d.L(B.a.ga8(a7).b-1,0,a8.length))
if(q.b.length!==0)B.a.i(r,q)}for(p=0;p<a7.length;p=n){o=B.d.L(a7[p].b-1,0,a8.length-1)
n=p+1
m=a7.length
l=a8.length
if(n<m)l=B.d.L(a7[n].b-1,o,l)
if(!(p<a7.length))return A.e(a7,p)
m=a7[p]
k=l===o?o+1:l
j=s.$3(m.a,o,k)
if(j.b.length!==0)B.a.i(r,j)}if(r.length!==0)return A.d_(r,"PDF",t)}a7=u.X
i=A.c([],a7)
h=A.ec(a8,0,i)
g=A.hp(t,"PDF",h,!0)
m=g.w
k=m.length
if(k>1){for(f=0,e=0;e<m.length;m.length===k||(0,A.l)(m),++e){j=m[e]
d=A.c([],a7)
for(c=j.b,b=c.length,a=0;a<c.length;c.length===b||(0,A.l)(c),++a){a0=c[a]
a1=h.length
a2=f
for(;;){a3=a2<a1
if(a3){if(!(a2>=0))return A.e(h,a2)
a4=h[a2]!==a0}else a4=!1
if(!a4)break;++a2}if(a3)f=a2+1
if(a3){if(!(a2>=0&&a2<i.length))return A.e(i,a2)
a1=i[a2]}else a1=d.length===0?0:B.a.gaa(d)
B.a.i(d,a1)}j.saU(d)}return g}r=A.c([],u.p)
for(a5=0;a7=a8.length,a5<a7;a5=a6){a6=a5+10
l=B.d.L(a6,0,a7)
j=s.$3(a8.length<=10?t:"Pages "+(a5+1)+"\u2013"+l,a5,l)
if(j.b.length!==0)B.a.i(r,j)}return A.d_(r,"PDF",t)},
cQ:function cQ(){},
cR:function cR(){},
cS:function cS(){},
cT:function cT(a,b,c,d){var _=this
_.a=a
_.b=b
_.c=c
_.d=d},
cz:function cz(){},
cA:function cA(){},
cB:function cB(){},
cC:function cC(a){this.a=a},
al(a){var t,s,r
if(a.length===0)return 0
t=A.ag(a,u.i)
B.a.ab(t)
s=t.length
r=s/2|0
if(!(r<s))return A.e(t,r)
return t[r]},
fY(a,b){var t,s,r=new A.cy(a,b),q=r.$1($.es())
if(J.H(q)!==0)return A.al(q)
t=r.$1($.eu())
if(J.H(t)!==0)return A.al(t)
s=r.$1($.ex())
if(J.H(s)!==0)return A.al(s)/0.68
return A.al(b)},
ho(a4,a5,a6){var t,s,r,q,p,o,n,m,l,k,j,i,h,g,f,e,d,c,b,a,a0,a1={},a2=A.c([],u.E),a3=new A.a6("")
a1.a=null
t=A.c([],u.t)
s=A.c([],u.s)
r=new A.cU(a1,a3,a2,s,t)
q=a4.length
p=Math.min(q,a5.length)
for(o=0,n=0;n<p;++n){if(!(n<q))return A.e(a4,n)
m=a4[n]
if(m==="\n"||m==="\r"){r.$0()
continue}if(!(n<a5.length))return A.e(a5,n)
l=a5[n].a
k=l[0]
j=l[1]
i=l[2]
h=l[3]
if(B.b.v(m).length===0||i<=k||j<=h){if(a1.a!=null)a3.a+=" "
continue}l=a6-j
g=a6-h
f=new A.m(k,l,i,g)
e=a1.a
if(e!=null){d=Math.max(g-l,A.al(t))
c=(l+g)/2
b=d*0.2
a=c>e.b-b&&c<e.d+b
a0=k-o
if(!a||a0>d*1.6||a0<-d*2)r.$0()}b=a1.a
if(b==null)a1.a=f
else a1.a=b.P(f)
a3.a+=m
B.a.i(t,g-l)
B.a.i(s,m)
o=i}r.$0()
return A.fy(a2)},
fy(a){var t,s,r,q,p,o,n,m,l,k,j,i,h,g,f,e,d,c=u.E,b=A.c([],c)
for(t=a.length,s=0;s<a.length;a.length===t||(0,A.l)(a),++s){r=a[s]
if(r.a.length===1)b.push(r)}B.a.G(b,new A.cr())
t=b.length
if(t<4)return a
q=u.n
p=A.c4(q)
o=A.c4(q)
for(s=0;s<b.length;b.length===t||(0,A.l)(b),++s){n=b[s]
if(o.J(0,n))continue
m=A.c([n],c)
for(q=b.length,l=n,k=0;k<b.length;b.length===q||(0,A.l)(b),++k){j=b[k]
i=j.b
h=i.b
g=l.b
f=g.b
if(h<=f||o.J(0,j))continue
e=g.a
d=g.c
g=g.d
f=Math.max(Math.max(d-e,g-f),2)*0.6
if(Math.abs((i.a+i.c)/2-(e+d)/2)<f&&h-g<f){B.a.i(m,j)
l=j}}if(m.length>=4){p.T(0,m)
o.T(0,m)}}if(p.a===0)return a
c=A.c([],c)
for(b=a.length,s=0;s<a.length;a.length===b||(0,A.l)(a),++s){r=a[s]
if(!p.J(0,r))c.push(r)}return c},
dZ(a,b){var t,s,r,q,p,o,n,m=u.G,l=A.c([],m)
for(t=a.length,s=0;s<a.length;a.length===t||(0,A.l)(a),++s){r=a[s]
l.push(b?new A.a8(r.a,r.c):new A.a8(r.b,r.d))}B.a.G(l,new A.cs())
q=A.c([],m)
p=B.a.ga8(l).b
for(m=A.f0(l,1,null,u.o),l=m.$ti,m=new A.J(m,m.gk(0),l.h("J<z.E>")),l=l.h("z.E");m.l();){t=m.d
if(t==null)t=l.a(t)
o=t.a
n=t.b
if(o>p)B.a.i(q,new A.a8(p,o))
p=Math.max(p,n)}return q},
hi(a5,a6,a7){var t,s,r,q,p,o,n,m,l,k,j,i,h,g,f,e,d,c,b,a,a0,a1,a2,a3,a4
if(a5.length===0)return new A.a4(B.q,a7)
t=u.t
s=A.c([],t)
for(r=a5.length,q=0;q<a5.length;a5.length===r||(0,A.l)(a5),++q)s.push(a5[q].c)
p=Math.max(A.al(s),1)
o=A.c([],u.c)
new A.cI(o,p).$2(a5,0)
A.fU(o,p)
n=A.c([],u.V)
m=A.c([],u.u)
for(s=o.length,r=u.w,l=u.r,k=u.E,q=0;q<o.length;o.length===s||(0,A.l)(o),++q){j=o[q]
B.a.G(j,new A.cF())
i=A.c([],k)
for(h=B.a.gn(j);h.l();){g=h.gm()
f=i.length===0?null:B.a.gaa(i)
if(f!=null){e=f.b
d=g.b
if(A.bg(e,d)&&d.a>=e.c-1){c=Math.max(f.c,g.c)
b=d.a-e.c>c*0.3?" ":""
B.a.t(i,i.length-1,new A.q(f.a+b+g.a,e.P(d),c))
continue}}B.a.i(i,new A.q(g.a,g.b,g.c))}a=new A.ah(i,r.a(new A.cG()),l).O(0,new A.cH())
a0=m.length
B.a.i(m,a)
h=A.c([],t)
for(a1=1;a1<i.length;++a1){g=i[a1].b.b
e=i[a1-1].b.b
if(g>e)h.push(g-e)}a2=h.length>=2?A.al(h):0
for(h=i.length,a3=0;a3<i.length;i.length===h||(0,A.l)(i),++a3){a4=i[a3]
B.a.i(n,new A.bz(a4.a,a4.b,a4.c,a0,a,a2))}}return new A.a4(n,a7)},
fU(a4,a5){var t,s,r,q,p,o,n,m,l,k,j,i,h,g,f,e,d,c,b,a,a0,a1,a2=new A.cu(),a3=new A.cx()
for(t=a5*0.3,s=a5*1.5,r=a5*2.5,q=u.n,p=0;o=p+1,n=a4.length,o<n;){if(!(p<n))return A.e(a4,p)
m=a2.$1(a4[p])
if(!(o<a4.length))return A.e(a4,o)
l=a2.$1(a4[o])
if(!(p<a4.length))return A.e(a4,p)
k=a3.$1(a4[p])
if(!(o<a4.length))return A.e(a4,o)
j=a3.$1(a4[o])
i=m.P(l)
n=m.c
h=l.c
g=Math.min(n,h)
f=m.a
e=l.a
d=Math.max(f,e)
c=l.b
b=m.d
a=c>=b-t&&c-b<s
c=n-f
b=h-e
a0=!1
if(g-d>=Math.min(c,b)*0.7)if(i.c-i.a<=Math.max(c,b)*1.15){n=Math.abs(f-e)<r||Math.abs(n-h)<a5
a0=n}a1=Math.abs(k-j)<=Math.max(k,j)*0.25
if(a&&a0&&a1){if(!(p<a4.length))return A.e(a4,p)
n=A.ag(a4[p],q)
if(!(o<a4.length))return A.e(a4,o)
B.a.T(n,a4[o])
B.a.t(a4,p,n)
B.a.aV(a4,o)}else p=o}},
fm(a,b){var t,s,r,q,p,o,n,m,l,k,j,i=A.ag(a,u.n)
B.a.G(i,new A.cn())
t=A.c([],u.t)
for(s=i.length,r=null,q=0;q<i.length;i.length===s||(0,A.l)(i),++q){p=i[q]
o=r!=null&&A.bg(r,p.b)
n=p.b
m=n.a
if(o)B.a.t(t,t.length-1,Math.min(B.a.gaa(t),m))
else{B.a.i(t,m)
r=n}}l=B.a.O(t,B.i)
i=u.ax
s=u.v
k=new A.A(t,i.a(new A.co(l,b)),s).gk(0)
j=new A.A(t,i.a(new A.cp(l,b)),s).gk(0)
if(k>=2){i=t.length
i=k+j>=i*0.85&&k>=i*0.5}else i=!1
return i},
e3(a){var t,s,r,q,p,o=A.c([],u.u)
for(t=a.length,s=0;s<a.length;a.length===t||(0,A.l)(a),++s)o.push(a[s].b)
B.a.G(o,new A.ct())
for(t=o.length,r=0,q=null,s=0;s<t;++s){p=o[s]
if(q==null||!A.bg(q,p)){++r
if(r>=3)return r
q=p}}return r},
fD(a,b){var t,s,r,q,p,o,n,m,l,k,j,i,h,g,f=A.c([],u.h)
for(t=a.length,s=b*0.8,r=t,q=0;q<r;l===t||(0,A.l)(a),++q,r=l){p=a[q]
for(o=p.b,n=o.c,m=0;l=a.length,m<l;a.length===r||(0,A.l)(a),++m){k=a[m]
if(p===k||!A.bg(o,k.b))continue
l=k.b.a
if(l-n>=s)B.a.i(f,new A.b8(n,l,o))}}for(t=f.length,s=b*0.4,r=b*0.5,q=0;q<t;++q){j=f[q]
for(o=j.b,n=j.a,l=j.c,i=0,m=0;m<t;++m){h=f[m]
if(j===h||A.bg(l,h.c))continue
g=h.b
if(Math.min(o,g)-Math.max(n,h.a)>s&&Math.abs(o-g)<r)++i}if(i>=3)return!0}return!1},
bg(a,b){var t=a.d,s=a.b,r=b.d,q=b.b,p=t-s>=r-q?a:b,o=p===a?b:a,n=o.d,m=o.b,l=n-m
if(Math.min(t,r)-Math.max(s,q)>l*0.5)return!0
t=p.d
s=p.b
r=t-s
return l<r*0.6&&n>=s-r*0.15&&m<=t},
ea(a,b){var t=a.b,s=b.d
if(!(t.d<s*0.075||t.b>s*0.925)||a.a.length>60)return""
t=A.y("\\d+",!0)
t=A.aC(a.a.toLowerCase(),t,"#")
s=A.y("\\s+",!0)
return B.b.v(A.aC(t,s," "))},
hj(a,b){var t,s,r,q,p,o,n,m=A.c([],u.V)
for(t=a.a,s=t.length,r=0;r<t.length;t.length===s||(0,A.l)(t),++r){q=t[r]
p=A.ea(q,a)
if(p.length!==0)if(!b.J(0,p)){o=$.ev()
o=o.b.test(q.a)}else o=!0
else o=!1
if(o)continue
B.a.i(m,q)}for(n=0,t="";n<m.length;++n){q=m[n]
if(n>0)if(A.fu(m[n-1],q))t+="\u2029\n"
t+=q.a+"\n"}return t.charCodeAt(0)==0?t:t},
fu(a,b){var t,s,r,q,p,o,n,m,l=a.c,k=b.c,j=Math.max(l,k),i=j>0?Math.abs(l-k)/j:0
if(!(i>0.4))k=i>0.25&&a.a.length>=10&&b.a.length>=10
else k=!0
if(k)return!0
k=$.ez()
t=a.a
s=k.b.test(t)
if(a.d!==b.d&&b.b.b<a.b.b)return s
r=a.e
q=Math.max(l,1)
l=b.b
k=l.b
p=a.b
o=a.f
o=o>0?o:b.f
if(o>0?k-p.b>o*1.4:k-p.d>q*1.2)return!0
k=r.a
if(l.a>k+q*1.2&&p.a<=k+q*0.5&&s)return!0
l=p.c
p=r.c
k=Math.max(q*3,(p-k)*0.2)
if(!s){n=A.y("^[a-z(]",!0)
m=n.b.test(b.a)}else m=!1
if(l<p-k&&!m&&!B.b.W(t,"-")&&!B.b.W(t,","))return!0
if(s&&l<p-q*1.5)return!0
return!1},
m:function m(a,b,c,d){var _=this
_.a=a
_.b=b
_.c=c
_.d=d},
q:function q(a,b,c){this.a=a
this.b=b
this.c=c},
bz:function bz(a,b,c,d,e,f){var _=this
_.a=a
_.b=b
_.c=c
_.d=d
_.e=e
_.f=f},
a4:function a4(a,b){this.a=a
this.d=b},
cy:function cy(a,b){this.a=a
this.b=b},
cU:function cU(a,b,c,d,e){var _=this
_.a=a
_.b=b
_.c=c
_.d=d
_.e=e},
cr:function cr(){},
cs:function cs(){},
cI:function cI(a,b){this.a=a
this.b=b},
cJ:function cJ(a){this.a=a},
cN:function cN(){},
cO:function cO(){},
cK:function cK(a){this.a=a},
cM:function cM(a,b,c,d){var _=this
_.a=a
_.b=b
_.c=c
_.d=d},
cL:function cL(a){this.a=a},
cF:function cF(){},
cG:function cG(){},
cH:function cH(){},
cu:function cu(){},
cv:function cv(){},
cw:function cw(){},
cx:function cx(){},
cn:function cn(){},
co:function co(a,b){this.a=a
this.b=b},
cp:function cp(a,b){this.a=a
this.b=b},
ct:function ct(){},
hn(b4){var t,s,r,q,p,o,n,m,l,k,j,i,h,g,f,e,d,c,b,a,a0,a1,a2,a3,a4,a5,a6,a7,a8,a9,b0,b1,b2,b3=null
try{a=u.l
t=a.a(B.f.aM(b4,b3))
s=A.c([],u.s)
r=A.c([],u.e)
for(a0=u.j,a=J.cY(a0.a(J.C(t,"pages")),a),a1=a.$ti,a=new A.J(a,a.gk(0),a1.h("J<O.E>")),a2=u.D,a3=u.H,a4=u.L,a1=a1.h("O.E");a.l();){a5=a.d
q=a5==null?a1.a(a5):a5
a6=A.db(J.C(q,"t"))
p=a6==null?"":a6
a5=a4.a(J.C(q,"r"))
o=J.cY(a5==null?B.h:a5,a3)
n=A.bT(J.C(q,"w"))
m=A.bT(J.C(q,"h"))
J.aD(s,p)
if(J.H(o.gI())!==J.H(p)*4||J.eF(p).length===0){J.aD(r,null)
continue}l=A.c([],a2)
k=0
for(;;){a5=k
a7=J.H(p)
if(typeof a5!=="number")return a5.b5()
if(!(a5<a7))break
a5=o
a7=k
if(typeof a7!=="number")return a7.a_()
a7=a5.$ti.y[1].a(J.C(a5.a,a7*4))
a5=o
a8=k
if(typeof a8!=="number")return a8.a_()
a8=a5.$ti.y[1].a(J.C(a5.a,a8*4+1))
a5=o
a9=k
if(typeof a9!=="number")return a9.a_()
a9=a5.$ti.y[1].a(J.C(a5.a,a9*4+2))
a5=o
b0=k
if(typeof b0!=="number")return b0.a_()
J.aD(l,new A.b9([a7,a8,a9,a5.$ti.y[1].a(J.C(a5.a,b0*4+3))]))
a5=k
if(typeof a5!=="number")return a5.b2()
k=a5+1}j=l
J.aD(r,A.hi(A.ho(p,j,m),n,m))}A.h3(s,r)
i=A.c([],u.q)
l=a4.a(J.C(t,"outline"))
l=J.cY(l==null?B.h:l,a0)
a=l.$ti
l=new A.J(l,l.gk(0),a.h("J<O.E>"))
a=a.h("O.E")
while(l.l()){a0=l.d
h=a0==null?a.a(a0):a0
if(B.b.v(A.K(J.C(h,0))).length!==0)J.aD(i,new A.a8(B.b.v(A.K(J.C(h,0))),B.c.aY(A.bT(J.C(h,1)))))}g=i
l=A.db(J.C(t,"name"))
if(l==null)l="PDF"
f=A.h5(s,g,l)
l=f.a
e=A.c([],u.J)
for(i=f.w,a=i.length,a0=u.N,a1=u.K,b1=0;b1<i.length;i.length===a||(0,A.l)(i),++b1){d=i[b1]
a2=d.a
a3=d.b
a4=d.c
J.aD(e,A.c3(["title",a2,"paras",a3,"pages",a4==null?B.p:a4],a0,a1))}l=B.f.a7(A.c3(["title",l,"chapters",e],a0,a1),b3)
return l}catch(b2){l=A.dk(b2)
if(l instanceof A.aI){c=l
l=u.N
return B.f.a7(A.c3(["error",c.a],l,l),b3)}else{b=l
l=u.N
l=B.f.a7(A.c3(["error","This PDF could not be read ("+A.r(b)+")."],l,l),b3)
return l}}},
hk(){var t,s=new A.cP()
if(typeof s=="function")A.cX(A.cZ("Attempting to rewrap a JS function."))
t=function(a,b){return function(c){return a(b,c,arguments.length)}}(A.fv,s)
t[$.dl()]=s
v.G.lanternPdfBook=t},
cP:function cP(){},
ef(a){return v.mangledGlobalNames[a]},
hv(a){throw A.w(new A.bA("Field '"+a+"' has been assigned during initialization."),new Error())},
fv(a,b,c){u.Z.a(a)
if(A.ak(c)>=1)return a.$1(b)
return a.$0()},
e9(a,b,c){A.h6(c,u.H,"T","min")
return Math.min(c.a(a),c.a(b))},
e7(a){var t=$.dm().aP(a)
if(t==null)t=null
else{t=t.b
if(1>=t.length)return A.e(t,1)
t=t[1]
t=t==null?null:t.length}return t==null?0:t}},B={}
var w=[A,J,B]
var $={}
A.d2.prototype={}
J.bt.prototype={
C(a,b){return a===b},
gq(a){return A.bC(a)},
j(a){return"Instance of '"+A.bD(a)+"'"},
gK(a){return A.a_(A.dc(this))}}
J.bv.prototype={
j(a){return String(a)},
gq(a){return a?519018:218159},
gK(a){return A.a_(u.y)},
$iX:1,
$in:1}
J.aK.prototype={
C(a,b){return null==b},
j(a){return"null"},
gq(a){return 0},
$iX:1}
J.au.prototype={$iat:1}
J.a2.prototype={
gq(a){return 0},
j(a){return String(a)}}
J.c8.prototype={}
J.Z.prototype={}
J.aM.prototype={
j(a){var t=a[$.eh()]
if(t==null)t=a[$.dl()]
if(t==null)return this.av(a)
return"JavaScript function for "+J.aE(t)},
$iV:1}
J.i.prototype={
U(a,b){return new A.T(a,A.u(a).h("@<1>").E(b).h("T<1,2>"))},
i(a,b){A.u(a).c.a(b)
a.$flags&1&&A.ap(a,29)
a.push(b)},
aV(a,b){var t
a.$flags&1&&A.ap(a,"removeAt",1)
t=a.length
if(b>=t)throw A.b(A.dG(b,null))
return a.splice(b,1)[0]},
aW(a,b){A.u(a).h("n(1)").a(b)
a.$flags&1&&A.ap(a,16)
this.aG(a,b,!0)},
aG(a,b,c){var t,s,r,q,p
A.u(a).h("n(1)").a(b)
t=[]
s=a.length
for(r=0;r<s;++r){q=a[r]
if(!b.$1(q))t.push(q)
if(a.length!==s)throw A.b(A.M(a))}p=t.length
if(p===s)return
this.sk(a,p)
for(r=0;r<t.length;++r)a[r]=t[r]},
T(a,b){var t
A.u(a).h("d<1>").a(b)
a.$flags&1&&A.ap(a,"addAll",2)
if(Array.isArray(b)){this.az(a,b)
return}for(t=J.bi(b);t.l();)a.push(t.gm())},
az(a,b){var t,s
u.b.a(b)
t=b.length
if(t===0)return
if(a===b)throw A.b(A.M(a))
for(s=0;s<t;++s)a.push(b[s])},
am(a){a.$flags&1&&A.ap(a,"clear","clear")
a.length=0},
aT(a,b){var t,s=A.dC(a.length,"",!1,u.N)
for(t=0;t<a.length;++t)this.t(s,t,A.r(a[t]))
return s.join(b)},
O(a,b){var t,s,r
A.u(a).h("1(1,1)").a(b)
t=a.length
if(t===0)throw A.b(A.bY())
if(0>=t)return A.e(a,0)
s=a[0]
for(r=1;r<t;++r){s=b.$2(s,a[r])
if(t!==a.length)throw A.b(A.M(a))}return s},
aR(a,b,c,d){var t,s,r
d.a(b)
A.u(a).E(d).h("1(1,2)").a(c)
t=a.length
for(s=b,r=0;r<t;++r){s=c.$2(s,a[r])
if(a.length!==t)throw A.b(A.M(a))}return s},
A(a,b){if(!(b>=0&&b<a.length))return A.e(a,b)
return a[b]},
ar(a,b,c){if(b<0||b>a.length)throw A.b(A.Q(b,0,a.length,"start",null))
if(c==null)c=a.length
else if(c<b||c>a.length)throw A.b(A.Q(c,b,a.length,"end",null))
if(b===c)return A.c([],A.u(a))
return A.c(a.slice(b,c),A.u(a))},
ga8(a){if(a.length>0)return a[0]
throw A.b(A.bY())},
gaa(a){var t=a.length
if(t>0)return a[t-1]
throw A.b(A.bY())},
aK(a,b){var t,s
A.u(a).h("n(1)").a(b)
t=a.length
for(s=0;s<t;++s){if(b.$1(a[s]))return!0
if(a.length!==t)throw A.b(A.M(a))}return!1},
G(a,b){var t,s,r,q,p,o=A.u(a)
o.h("h(1,1)?").a(b)
a.$flags&2&&A.ap(a,"sort")
t=a.length
if(t<2)return
if(b==null)b=J.fH()
if(t===2){s=a[0]
r=a[1]
o=b.$2(s,r)
if(typeof o!=="number")return o.b4()
if(o>0){a[0]=r
a[1]=s}return}q=0
if(o.c.b(null))for(p=0;p<a.length;++p)if(a[p]===void 0){a[p]=null;++q}a.sort(A.h7(b,2))
if(q>0)this.aH(a,q)},
ab(a){return this.G(a,null)},
aH(a,b){var t,s=a.length
for(;t=s-1,s>0;s=t)if(a[t]===null){a[t]=void 0;--b
if(b===0)break}},
gp(a){return a.length===0},
gF(a){return a.length!==0},
j(a){return A.d1(a,"[","]")},
gn(a){return new J.ac(a,a.length,A.u(a).h("ac<1>"))},
gq(a){return A.bC(a)},
gk(a){return a.length},
sk(a,b){a.$flags&1&&A.ap(a,"set length","change the length of")
if(b<0)throw A.b(A.Q(b,0,null,"newLength",null))
if(b>a.length)A.u(a).c.a(null)
a.length=b},
D(a,b){A.ak(b)
if(!(b>=0&&b<a.length))throw A.b(A.dg(a,b))
return a[b]},
t(a,b,c){A.u(a).c.a(c)
a.$flags&2&&A.ap(a)
if(!(b>=0&&b<a.length))throw A.b(A.dg(a,b))
a[b]=c},
$ik:1,
$id:1,
$io:1}
J.bu.prototype={
b_(a){var t,s,r
if(!Array.isArray(a))return null
t=a.$flags|0
if((t&4)!==0)s="const, "
else if((t&2)!==0)s="unmodifiable, "
else s=(t&1)!==0?"fixed, ":""
r="Instance of '"+A.bD(a)+"'"
if(s==="")return r
return r+" ("+s+"length: "+a.length+")"}}
J.bZ.prototype={}
J.ac.prototype={
gm(){var t=this.d
return t==null?this.$ti.c.a(t):t},
l(){var t,s=this,r=s.a,q=r.length
if(s.b!==q){r=A.l(r)
throw A.b(r)}t=s.c
if(t>=q){s.d=null
return!1}s.d=r[t]
s.c=t+1
return!0},
$it:1}
J.as.prototype={
u(a,b){var t
A.bT(b)
if(a<b)return-1
else if(a>b)return 1
else if(a===b){if(a===0){t=this.gX(b)
if(this.gX(a)===t)return 0
if(this.gX(a))return-1
return 1}return 0}else if(isNaN(a)){if(isNaN(b))return 0
return 1}else return-1},
gX(a){return a===0?1/a<0:a<0},
aY(a){var t
if(a>=-2147483648&&a<=2147483647)return a|0
if(isFinite(a)){t=a<0?Math.ceil(a):Math.floor(a)
return t+0}throw A.b(A.ce(""+a+".toInt()"))},
aL(a){var t,s
if(a>=0){if(a<=2147483647){t=a|0
return a===t?t:t+1}}else if(a>=-2147483648)return a|0
s=Math.ceil(a)
if(isFinite(s))return s
throw A.b(A.ce(""+a+".ceil()"))},
aQ(a){var t,s
if(a>=0){if(a<=2147483647)return a|0}else if(a>=-2147483648){t=a|0
return a===t?t:t-1}s=Math.floor(a)
if(isFinite(s))return s
throw A.b(A.ce(""+a+".floor()"))},
L(a,b,c){if(B.d.u(b,c)>0)throw A.b(A.h4(b))
if(this.u(a,b)<0)return b
if(this.u(a,c)>0)return c
return a},
Y(a,b){var t
if(b>20)throw A.b(A.Q(b,0,20,"fractionDigits",null))
t=a.toFixed(b)
if(a===0&&this.gX(a))return"-"+t
return t},
j(a){if(a===0&&1/a<0)return"-0.0"
else return""+a},
gq(a){var t,s,r,q,p=a|0
if(a===p)return p&536870911
t=Math.abs(a)
s=Math.log(t)/0.6931471805599453|0
r=Math.pow(2,s)
q=t<1?t/r:r/t
return((q*9007199254740992|0)+(q*3542243181176521|0))*599197+s*1259&536870911},
aj(a,b){var t
if(a>0)t=this.aI(a,b)
else{t=b>31?31:b
t=a>>t>>>0}return t},
aI(a,b){return b>31?0:a>>>b},
gK(a){return A.a_(u.H)},
$iU:1,
$ia:1,
$iB:1}
J.aJ.prototype={
gK(a){return A.a_(u.S)},
$iX:1,
$ih:1}
J.bw.prototype={
gK(a){return A.a_(u.i)},
$iX:1}
J.a1.prototype={
a6(a,b,c){var t=b.length
if(c>t)throw A.b(A.Q(c,0,t,null,null))
return new A.bR(b,a,c)},
al(a,b){return this.a6(a,b,0)},
W(a,b){var t=b.length,s=a.length
if(t>s)return!1
return b===this.au(a,s-t)},
aX(a,b,c){return A.ee(a,b,c,0)},
H(a,b,c){return a.substring(b,A.eY(b,c,a.length))},
au(a,b){return this.H(a,b,null)},
v(a){var t,s,r,q=a.trim(),p=q.length
if(p===0)return q
if(0>=p)return A.e(q,0)
if(q.charCodeAt(0)===133){t=J.eU(q,1)
if(t===p)return""}else t=0
s=p-1
if(!(s>=0))return A.e(q,s)
r=q.charCodeAt(s)===133?J.dy(q,s):p
if(t===0&&r===p)return q
return q.substring(t,r)},
aZ(a){var t,s=a.trimEnd(),r=s.length
if(r===0)return s
t=r-1
if(!(t>=0))return A.e(s,t)
if(s.charCodeAt(t)!==133)return s
return s.substring(0,J.dy(s,t))},
J(a,b){return A.hq(a,b,0)},
u(a,b){var t
A.K(b)
if(a===b)t=0
else t=a<b?-1:1
return t},
j(a){return a},
gq(a){var t,s,r
for(t=a.length,s=0,r=0;r<t;++r){s=s+a.charCodeAt(r)&536870911
s=s+((s&524287)<<10)&536870911
s^=s>>6}s=s+((s&67108863)<<3)&536870911
s^=s>>11
return s+((s&16383)<<15)&536870911},
gK(a){return A.a_(u.N)},
gk(a){return a.length},
$iX:1,
$iU:1,
$ibB:1,
$if:1}
A.a7.prototype={
gn(a){return new A.aF(J.bi(this.gI()),A.E(this).h("aF<1,2>"))},
gk(a){return J.H(this.gI())},
gp(a){return J.eC(this.gI())},
gF(a){return J.eD(this.gI())},
j(a){return J.aE(this.gI())}}
A.aF.prototype={
l(){return this.a.l()},
gm(){return this.$ti.y[1].a(this.a.gm())},
$it:1}
A.ad.prototype={
gI(){return this.a}}
A.b4.prototype={$ik:1}
A.b3.prototype={
D(a,b){return this.$ti.y[1].a(J.C(this.a,b))},
$ik:1,
$io:1}
A.T.prototype={
U(a,b){return new A.T(this.a,this.$ti.h("@<1>").E(b).h("T<1,2>"))},
gI(){return this.a}}
A.bA.prototype={
j(a){return"LateInitializationError: "+this.a}}
A.ca.prototype={}
A.k.prototype={}
A.z.prototype={
gn(a){var t=this
return new A.J(t,t.gk(t),A.E(t).h("J<z.E>"))},
gp(a){return this.gk(this)===0},
O(a,b){var t,s,r,q=this
A.E(q).h("z.E(z.E,z.E)").a(b)
t=q.gk(q)
if(t===0)throw A.b(A.bY())
s=q.A(0,0)
for(r=1;r<t;++r){s=b.$2(s,q.A(0,r))
if(t!==q.gk(q))throw A.b(A.M(q))}return s}}
A.b_.prototype={
gaC(){var t=J.H(this.a),s=this.c
if(s==null||s>t)return t
return s},
gaJ(){var t=J.H(this.a),s=this.b
if(s>t)return t
return s},
gk(a){var t,s=J.H(this.a),r=this.b
if(r>=s)return 0
t=this.c
if(t==null||t>=s)return s-r
return t-r},
A(a,b){var t=this,s=t.gaJ()+b
if(b<0||s>=t.gaC())throw A.b(A.d0(b,t.gk(0),t,"index"))
return J.dp(t.a,s)}}
A.J.prototype={
gm(){var t=this.d
return t==null?this.$ti.c.a(t):t},
l(){var t,s=this,r=s.a,q=r.gk(r)
if(s.b!==q)throw A.b(A.M(r))
t=s.c
if(t>=q){s.d=null
return!1}s.d=r.A(0,t);++s.c
return!0},
$it:1}
A.aS.prototype={
gn(a){var t=this.a
return new A.aT(t.gn(t),this.b,A.E(this).h("aT<1,2>"))},
gk(a){var t=this.a
return t.gk(t)},
gp(a){var t=this.a
return t.gp(t)}}
A.aT.prototype={
l(){var t=this,s=t.b
if(s.l()){t.a=t.c.$1(s.gm())
return!0}t.a=null
return!1},
gm(){var t=this.a
return t==null?this.$ti.y[1].a(t):t},
$it:1}
A.ah.prototype={
gk(a){return J.H(this.a)},
A(a,b){return this.b.$1(J.dp(this.a,b))}}
A.A.prototype={
gn(a){return new A.b2(J.bi(this.a),this.b,this.$ti.h("b2<1>"))}}
A.b2.prototype={
l(){var t,s
for(t=this.a,s=this.b;t.l();)if(s.$1(t.gm()))return!0
return!1},
gm(){return this.a.gm()},
$it:1}
A.bf.prototype={}
A.a8.prototype={$r:"+(1,2)",$s:1}
A.b8.prototype={$r:"+(1,2,3)",$s:2}
A.b9.prototype={$r:"+(1,2,3,4)",$s:3}
A.b5.prototype={
gm(){var t=this.d
return t==null?this.$ti.c.a(t):t},
l(){var t=this,s=t.c
if(s>=t.b){t.d=null
return!1}t.d=t.a[s]
t.c=s+1
return!0},
$it:1}
A.aG.prototype={
i(a,b){A.E(this).c.a(b)
A.eO()}}
A.aH.prototype={
gk(a){return this.b},
gp(a){return this.b===0},
gF(a){return this.b!==0},
gn(a){var t,s=this,r=s.$keys
if(r==null){r=Object.keys(s.a)
s.$keys=r}t=r
return new A.b5(t,t.length,s.$ti.h("b5<1>"))}}
A.bs.prototype={
C(a,b){if(b==null)return!1
return b instanceof A.ar&&this.a.C(0,b.a)&&A.di(this)===A.di(b)},
gq(a){return A.c7(this.a,A.di(this),B.e,B.e)},
j(a){var t=B.a.aT([A.a_(this.$ti.c)],", ")
return this.a.j(0)+" with "+("<"+t+">")}}
A.ar.prototype={
$2(a,b){return this.a.$1$2(a,b,this.$ti.y[0])},
$S(){return A.hh(A.cD(this.a),this.$ti)}}
A.aY.prototype={}
A.cc.prototype={
B(a){var t,s,r=this,q=new RegExp(r.a).exec(a)
if(q==null)return null
t=Object.create(null)
s=r.b
if(s!==-1)t.arguments=q[s+1]
s=r.c
if(s!==-1)t.argumentsExpr=q[s+1]
s=r.d
if(s!==-1)t.expr=q[s+1]
s=r.e
if(s!==-1)t.method=q[s+1]
s=r.f
if(s!==-1)t.receiver=q[s+1]
return t}}
A.aV.prototype={
j(a){return"Null check operator used on a null value"}}
A.bx.prototype={
j(a){var t,s=this,r="NoSuchMethodError: method not found: '",q=s.b
if(q==null)return"NoSuchMethodError: "+s.a
t=s.c
if(t==null)return r+q+"' ("+s.a+")"
return r+q+"' on '"+t+"' ("+s.a+")"}}
A.bJ.prototype={
j(a){var t=this.a
return t.length===0?"Error":"Error: "+t}}
A.c6.prototype={
j(a){return"Throw of null ('"+(this.a===null?"null":"undefined")+"' from JavaScript)"}}
A.D.prototype={
j(a){var t=this.constructor,s=t==null?null:t.name
return"Closure '"+A.eg(s==null?"unknown":s)+"'"},
$iV:1,
gb3(){return this},
$C:"$1",
$R:1,
$D:null}
A.bl.prototype={$C:"$0",$R:0}
A.bm.prototype={$C:"$2",$R:2}
A.bI.prototype={}
A.bG.prototype={
j(a){var t=this.$static_name
if(t==null)return"Closure of unknown static method"
return"Closure '"+A.eg(t)+"'"}}
A.aq.prototype={
C(a,b){if(b==null)return!1
if(this===b)return!0
if(!(b instanceof A.aq))return!1
return this.$_target===b.$_target&&this.a===b.a},
gq(a){return(A.eb(this.a)^A.bC(this.$_target))>>>0},
j(a){return"Closure '"+this.$_name+"' of "+("Instance of '"+A.bD(this.a)+"'")}}
A.bE.prototype={
j(a){return"RuntimeError: "+this.a}}
A.ae.prototype={
gk(a){return this.a},
gp(a){return this.a===0},
gM(){return new A.af(this,A.E(this).h("af<1>"))},
D(a,b){var t,s,r,q,p=null
if(typeof b=="string"){t=this.b
if(t==null)return p
s=t[b]
r=s==null?p:s.b
return r}else if(typeof b=="number"&&(b&0x3fffffff)===b){q=this.c
if(q==null)return p
s=q[b]
r=s==null?p:s.b
return r}else return this.aS(b)},
aS(a){var t,s,r=this.d
if(r==null)return null
t=this.aE(r,a)
s=this.ao(t,a)
if(s<0)return null
return t[s].b},
t(a,b,c){var t,s,r,q,p,o,n=this,m=A.E(n)
m.c.a(b)
m.y[1].a(c)
if(typeof b=="string"){t=n.b
n.ad(t==null?n.b=n.a4():t,b,c)}else if(typeof b=="number"&&(b&0x3fffffff)===b){s=n.c
n.ad(s==null?n.c=n.a4():s,b,c)}else{r=n.d
if(r==null)r=n.d=n.a4()
q=n.an(b)
p=r[q]
if(p==null)r[q]=[n.a5(b,c)]
else{o=n.ao(p,b)
if(o>=0)p[o].b=c
else p.push(n.a5(b,c))}}},
N(a,b){var t,s,r=this
A.E(r).h("~(1,2)").a(b)
t=r.e
s=r.r
while(t!=null){b.$2(t.a,t.b)
if(s!==r.r)throw A.b(A.M(r))
t=t.c}},
ad(a,b,c){var t,s=A.E(this)
s.c.a(b)
s.y[1].a(c)
t=a[b]
if(t==null)a[b]=this.a5(b,c)
else t.b=c},
a5(a,b){var t=this,s=A.E(t),r=new A.c2(s.c.a(a),s.y[1].a(b))
if(t.e==null)t.e=t.f=r
else t.f=t.f.c=r;++t.a
t.r=t.r+1&1073741823
return r},
an(a){return J.G(a)&1073741823},
aE(a,b){return a[this.an(b)]},
ao(a,b){var t,s
if(a==null)return-1
t=a.length
for(s=0;s<t;++s)if(J.ab(a[s].a,b))return s
return-1},
j(a){return A.dD(this)},
a4(){var t=Object.create(null)
t["<non-identifier-key>"]=t
delete t["<non-identifier-key>"]
return t},
$idB:1}
A.c2.prototype={}
A.af.prototype={
gk(a){return this.a.a},
gp(a){return this.a.a===0},
gn(a){var t=this.a
return new A.aQ(t,t.r,t.e,this.$ti.h("aQ<1>"))}}
A.aQ.prototype={
gm(){return this.d},
l(){var t,s=this,r=s.a
if(s.b!==r.r)throw A.b(A.M(r))
t=s.c
if(t==null){s.d=null
return!1}else{s.d=t.a
s.c=t.c
return!0}},
$it:1}
A.aO.prototype={
gk(a){return this.a.a},
gp(a){return this.a.a===0},
gn(a){var t=this.a
return new A.aP(t,t.r,t.e,this.$ti.h("aP<1,2>"))}}
A.aP.prototype={
gm(){var t=this.d
t.toString
return t},
l(){var t,s=this,r=s.a
if(s.b!==r.r)throw A.b(A.M(r))
t=s.c
if(t==null){s.d=null
return!1}else{s.d=new A.a3(t.a,t.b,s.$ti.h("a3<1,2>"))
s.c=t.c
return!0}},
$it:1}
A.S.prototype={
j(a){return this.ak(!1)},
ak(a){var t,s,r,q,p,o=this.aD(),n=this.S(),m=(a?"Record ":"")+"("
for(t=o.length,s="",r=0;r<t;++r,s=", "){m+=s
q=o[r]
if(typeof q=="string")m=m+q+": "
if(!(r<n.length))return A.e(n,r)
p=n[r]
m=a?m+A.dF(p):m+A.r(p)}m+=")"
return m.charCodeAt(0)==0?m:m},
aD(){var t,s=this.$s
while($.cj.length<=s)B.a.i($.cj,null)
t=$.cj[s]
if(t==null){t=this.aA()
B.a.t($.cj,s,t)}return t},
aA(){var t,s,r,q=this.$r,p=q.indexOf("("),o=q.substring(1,p),n=q.substring(p),m=n==="()"?0:n.replace(/[^,]/g,"").length+1,l=A.c(new Array(m),u.f)
for(t=0;t<m;++t)l[t]=t
if(o!==""){s=o.split(",")
t=s.length
for(r=m;t>0;){--r;--t
B.a.t(l,r,s[t])}}l=A.eW(l,!1,u.K)
l.$flags=3
return l}}
A.aw.prototype={
S(){return[this.a,this.b]},
C(a,b){if(b==null)return!1
return b instanceof A.aw&&this.$s===b.$s&&J.ab(this.a,b.a)&&J.ab(this.b,b.b)},
gq(a){return A.c7(this.$s,this.a,this.b,B.e)}}
A.ax.prototype={
S(){return[this.a,this.b,this.c]},
C(a,b){var t=this
if(b==null)return!1
return b instanceof A.ax&&t.$s===b.$s&&J.ab(t.a,b.a)&&J.ab(t.b,b.b)&&J.ab(t.c,b.c)},
gq(a){var t=this
return A.c7(t.$s,t.a,t.b,t.c)}}
A.ay.prototype={
S(){return this.a},
C(a,b){if(b==null)return!1
return b instanceof A.ay&&this.$s===b.$s&&A.fb(this.a,b.a)},
gq(a){return A.c7(this.$s,A.eX(this.a),B.e,B.e)}}
A.aL.prototype={
j(a){return"RegExp/"+this.a+"/"+this.b.flags},
gah(){var t=this,s=t.c
if(s!=null)return s
s=t.b
return t.c=A.dz(t.a,s.multiline,!s.ignoreCase,s.unicode,s.dotAll,"g")},
aP(a){var t=this.b.exec(a)
if(t==null)return null
return new A.b7(t)},
a6(a,b,c){var t=b.length
if(c>t)throw A.b(A.Q(c,0,t,null,null))
return new A.bK(this,b,c)},
al(a,b){return this.a6(0,b,0)},
af(a,b){var t,s=this.gah()
if(s==null)s=A.da(s)
s.lastIndex=b
t=s.exec(a)
if(t==null)return null
return new A.b7(t)},
$ibB:1,
$ic9:1}
A.b7.prototype={
gac(){return this.b.index},
gV(){var t=this.b
return t.index+t[0].length},
$iav:1,
$iaX:1}
A.bK.prototype={
gn(a){return new A.bL(this.a,this.b,this.c)}}
A.bL.prototype={
gm(){var t=this.d
return t==null?u.a0.a(t):t},
l(){var t,s,r,q,p,o,n=this,m=n.b
if(m==null)return!1
t=n.c
s=m.length
if(t<=s){r=n.a
q=r.af(m,t)
if(q!=null){n.d=q
p=q.gV()
if(q.b.index===p){t=!1
if(r.b.unicode){r=n.c
o=r+1
if(o<s){if(!(r>=0&&r<s))return A.e(m,r)
r=m.charCodeAt(r)
if(r>=55296&&r<=56319){if(!(o>=0))return A.e(m,o)
t=m.charCodeAt(o)
t=t>=56320&&t<=57343}}}p=(t?p+1:p)+1}n.c=p
return!0}}n.b=n.d=null
return!1},
$it:1}
A.bH.prototype={
gV(){return this.a+this.c.length},
$iav:1,
gac(){return this.a}}
A.bR.prototype={
gn(a){return new A.bS(this.a,this.b,this.c)}}
A.bS.prototype={
l(){var t,s,r=this,q=r.c,p=r.b,o=p.length,n=r.a,m=n.length
if(q+o>m){r.d=null
return!1}t=n.indexOf(p,q)
if(t<0){r.c=m+1
r.d=null
return!1}s=t+o
r.d=new A.bH(t,p)
r.c=s===r.c?s+1:s
return!0},
gm(){var t=this.d
t.toString
return t},
$it:1}
A.R.prototype={
h(a){return A.be(v.typeUniverse,this,a)},
E(a){return A.dT(v.typeUniverse,this,a)}}
A.bN.prototype={}
A.ck.prototype={
j(a){return A.F(this.a,null)}}
A.bM.prototype={
j(a){return this.a}}
A.az.prototype={}
A.b6.prototype={
gn(a){var t=this,s=new A.ai(t,t.r,t.$ti.h("ai<1>"))
s.c=t.e
return s},
gk(a){return this.a},
gp(a){return this.a===0},
gF(a){return this.a!==0},
J(a,b){var t,s
if(typeof b=="string"&&b!=="__proto__"){t=this.b
if(t==null)return!1
return u.M.a(t[b])!=null}else{s=this.aB(b)
return s}},
aB(a){var t=this.d
if(t==null)return!1
return this.ag(t[J.G(a)&1073741823],a)>=0},
i(a,b){var t,s,r=this
r.$ti.c.a(b)
if(typeof b=="string"&&b!=="__proto__"){t=r.b
return r.ae(t==null?r.b=A.d6():t,b)}else if(typeof b=="number"&&(b&1073741823)===b){s=r.c
return r.ae(s==null?r.c=A.d6():s,b)}else return r.aw(b)},
aw(a){var t,s,r,q=this
q.$ti.c.a(a)
t=q.d
if(t==null)t=q.d=A.d6()
s=J.G(a)&1073741823
r=t[s]
if(r==null)t[s]=[q.a1(a)]
else{if(q.ag(r,a)>=0)return!1
r.push(q.a1(a))}return!0},
ae(a,b){this.$ti.c.a(b)
if(u.M.a(a[b])!=null)return!1
a[b]=this.a1(b)
return!0},
a1(a){var t=this,s=new A.bQ(t.$ti.c.a(a))
if(t.e==null)t.e=t.f=s
else t.f=t.f.b=s;++t.a
t.r=t.r+1&1073741823
return s},
ag(a,b){var t,s
if(a==null)return-1
t=a.length
for(s=0;s<t;++s)if(J.ab(a[s].a,b))return s
return-1}}
A.bQ.prototype={}
A.ai.prototype={
gm(){var t=this.d
return t==null?this.$ti.c.a(t):t},
l(){var t=this,s=t.c,r=t.a
if(t.b!==r.r)throw A.b(A.M(r))
else if(s==null){t.d=null
return!1}else{t.d=t.$ti.h("1?").a(s.a)
t.c=s.b
return!0}},
$it:1}
A.O.prototype={
gn(a){return new A.J(this,this.gk(0),this.$ti.h("J<O.E>"))},
A(a,b){return this.$ti.y[1].a(J.C(this.a,b))},
gp(a){return J.H(this.a)===0},
gF(a){return J.H(this.a)!==0},
U(a,b){return new A.T(this,this.$ti.h("@<O.E>").E(b).h("T<1,2>"))},
j(a){return A.d1(this,"[","]")}}
A.I.prototype={
N(a,b){var t,s,r,q=A.E(this)
q.h("~(I.K,I.V)").a(b)
for(t=this.gM(),t=t.gn(t),q=q.h("I.V");t.l();){s=t.gm()
r=this.D(0,s)
b.$2(s,r==null?q.a(r):r)}},
gk(a){var t=this.gM()
return t.gk(t)},
gp(a){var t=this.gM()
return t.gp(t)},
j(a){return A.dD(this)},
$iaR:1}
A.c5.prototype={
$2(a,b){var t,s=this.a
if(!s.a)this.b.a+=", "
s.a=!1
s=this.b
t=A.r(a)
s.a=(s.a+=t)+": "
t=A.r(b)
s.a+=t},
$S:3}
A.a5.prototype={
gp(a){return this.gk(this)===0},
gF(a){return this.gk(this)!==0},
T(a,b){var t,s
A.E(this).h("d<1>").a(b)
for(t=b.length,s=0;s<b.length;b.length===t||(0,A.l)(b),++s)this.i(0,b[s])},
j(a){return A.d1(this,"{","}")},
$ik:1,
$id:1}
A.ba.prototype={}
A.bO.prototype={
D(a,b){var t,s=this.b
if(s==null)return this.c.D(0,b)
else if(typeof b!="string")return null
else{t=s[b]
return typeof t=="undefined"?this.aF(b):t}},
gk(a){return this.b==null?this.c.a:this.R().length},
gp(a){return this.gk(0)===0},
gM(){if(this.b==null){var t=this.c
return new A.af(t,A.E(t).h("af<1>"))}return new A.bP(this)},
N(a,b){var t,s,r,q,p=this
u.cQ.a(b)
if(p.b==null)return p.c.N(0,b)
t=p.R()
for(s=0;s<t.length;++s){r=t[s]
q=p.b[r]
if(typeof q=="undefined"){q=A.cq(p.a[r])
p.b[r]=q}b.$2(r,q)
if(t!==p.c)throw A.b(A.M(p))}},
R(){var t=u.L.a(this.c)
if(t==null)t=this.c=A.c(Object.keys(this.a),u.s)
return t},
aF(a){var t
if(!Object.prototype.hasOwnProperty.call(this.a,a))return null
t=A.cq(this.a[a])
return this.b[a]=t}}
A.bP.prototype={
gk(a){return this.a.gk(0)},
A(a,b){var t=this.a
if(t.b==null)t=t.gM().A(0,b)
else{t=t.R()
if(!(b>=0&&b<t.length))return A.e(t,b)
t=t[b]}return t},
gn(a){var t=this.a
if(t.b==null){t=t.gM()
t=t.gn(t)}else{t=t.R()
t=new J.ac(t,t.length,A.u(t).h("ac<1>"))}return t}}
A.bn.prototype={}
A.bp.prototype={}
A.aN.prototype={
j(a){var t=A.bq(this.a)
return(this.b!=null?"Converting object to an encodable object failed:":"Converting object did not return an encodable object:")+" "+t}}
A.by.prototype={
j(a){return"Cyclic error in JSON stringify"}}
A.c_.prototype={
aM(a,b){var t=A.fV(a,this.gaN().a)
return t},
a7(a,b){var t=A.f2(a,this.gaO().b,null)
return t},
gaO(){return B.o},
gaN(){return B.n}}
A.c1.prototype={}
A.c0.prototype={}
A.ch.prototype={
aq(a){var t,s,r,q,p,o,n=a.length
for(t=this.c,s=0,r=0;r<n;++r){q=a.charCodeAt(r)
if(q>92){if(q>=55296){p=q&64512
if(p===55296){o=r+1
o=!(o<n&&(a.charCodeAt(o)&64512)===56320)}else o=!1
if(!o)if(p===56320){p=r-1
p=!(p>=0&&(a.charCodeAt(p)&64512)===55296)}else p=!1
else p=!0
if(p){if(r>s)t.a+=B.b.H(a,s,r)
s=r+1
p=A.x(92)
t.a+=p
p=A.x(117)
t.a+=p
p=A.x(100)
t.a+=p
p=q>>>8&15
p=A.x(p<10?48+p:87+p)
t.a+=p
p=q>>>4&15
p=A.x(p<10?48+p:87+p)
t.a+=p
p=q&15
p=A.x(p<10?48+p:87+p)
t.a+=p}}continue}if(q<32){if(r>s)t.a+=B.b.H(a,s,r)
s=r+1
p=A.x(92)
t.a+=p
switch(q){case 8:p=A.x(98)
t.a+=p
break
case 9:p=A.x(116)
t.a+=p
break
case 10:p=A.x(110)
t.a+=p
break
case 12:p=A.x(102)
t.a+=p
break
case 13:p=A.x(114)
t.a+=p
break
default:p=A.x(117)
t.a+=p
p=A.x(48)
t.a=(t.a+=p)+p
p=q>>>4&15
p=A.x(p<10?48+p:87+p)
t.a+=p
p=q&15
p=A.x(p<10?48+p:87+p)
t.a+=p
break}}else if(q===34||q===92){if(r>s)t.a+=B.b.H(a,s,r)
s=r+1
p=A.x(92)
t.a+=p
p=A.x(q)
t.a+=p}}if(s===0)t.a+=a
else if(s<n)t.a+=B.b.H(a,s,n)},
a0(a){var t,s,r,q
for(t=this.a,s=t.length,r=0;r<s;++r){q=t[r]
if(a==null?q==null:a===q)throw A.b(new A.by(a,null))}B.a.i(t,a)},
Z(a){var t,s,r,q,p=this
if(p.ap(a))return
p.a0(a)
try{t=p.b.$1(a)
if(!p.ap(t)){r=A.dA(a,null,p.gai())
throw A.b(r)}r=p.a
if(0>=r.length)return A.e(r,-1)
r.pop()}catch(q){s=A.dk(q)
r=A.dA(a,s,p.gai())
throw A.b(r)}},
ap(a){var t,s,r=this
if(typeof a=="number"){if(!isFinite(a))return!1
r.c.a+=B.c.j(a)
return!0}else if(a===!0){r.c.a+="true"
return!0}else if(a===!1){r.c.a+="false"
return!0}else if(a==null){r.c.a+="null"
return!0}else if(typeof a=="string"){t=r.c
t.a+='"'
r.aq(a)
t.a+='"'
return!0}else if(u.j.b(a)){r.a0(a)
r.b0(a)
t=r.a
if(0>=t.length)return A.e(t,-1)
t.pop()
return!0}else if(a instanceof A.I){r.a0(a)
s=r.b1(a)
t=r.a
if(0>=t.length)return A.e(t,-1)
t.pop()
return s}else return!1},
b0(a){var t,s,r=this.c
r.a+="["
t=J.bV(a)
if(t.gF(a)){this.Z(t.D(a,0))
for(s=1;s<t.gk(a);++s){r.a+=","
this.Z(t.D(a,s))}}r.a+="]"},
b1(a){var t,s,r,q,p,o,n=this,m={}
if(a.gp(a)){n.c.a+="{}"
return!0}t=a.gk(a)*2
s=A.dC(t,null,!1,u.O)
r=m.a=0
m.b=!0
a.N(0,new A.ci(m,s))
if(!m.b)return!1
q=n.c
q.a+="{"
for(p='"';r<t;r+=2,p=',"'){q.a+=p
n.aq(A.K(s[r]))
q.a+='":'
o=r+1
if(!(o<t))return A.e(s,o)
n.Z(s[o])}q.a+="}"
return!0}}
A.ci.prototype={
$2(a,b){var t,s
if(typeof a!="string")this.a.b=!1
t=this.b
s=this.a
B.a.t(t,s.a++,a)
B.a.t(t,s.a++,b)},
$S:3}
A.cg.prototype={
gai(){var t=this.c.a
return t.charCodeAt(0)==0?t:t}}
A.p.prototype={}
A.bj.prototype={
j(a){var t=this.a
if(t!=null)return"Assertion failed: "+A.bq(t)
return"Assertion failed"}}
A.b0.prototype={}
A.a0.prototype={
ga3(){return"Invalid argument"+(!this.a?"(s)":"")},
ga2(){return""},
j(a){var t=this,s=t.c,r=s==null?"":" ("+s+")",q=t.d,p=q==null?"":": "+q,o=t.ga3()+r+p
if(!t.a)return o
return o+t.ga2()+": "+A.bq(t.ga9())},
ga9(){return this.b}}
A.aW.prototype={
ga9(){return A.dW(this.b)},
ga3(){return"RangeError"},
ga2(){var t,s=this.e,r=this.f
if(s==null)t=r!=null?": Not less than or equal to "+A.r(r):""
else if(r==null)t=": Not greater than or equal to "+A.r(s)
else if(r>s)t=": Not in inclusive range "+A.r(s)+".."+A.r(r)
else t=r<s?": Valid value range is empty":": Only valid value is "+A.r(s)
return t}}
A.br.prototype={
ga9(){return A.ak(this.b)},
ga3(){return"RangeError"},
ga2(){if(A.ak(this.b)<0)return": index must not be negative"
var t=this.f
if(t===0)return": no indices are valid"
return": index should be less than "+t},
gk(a){return this.f}}
A.b1.prototype={
j(a){return"Unsupported operation: "+this.a}}
A.bF.prototype={
j(a){return"Bad state: "+this.a}}
A.bo.prototype={
j(a){var t=this.a
if(t==null)return"Concurrent modification during iteration."
return"Concurrent modification during iteration: "+A.bq(t)+"."}}
A.aZ.prototype={
j(a){return"Stack Overflow"},
$ip:1}
A.cf.prototype={
j(a){return"Exception: "+this.a}}
A.aI.prototype={
j(a){var t=this.a,s=""!==t?"FormatException: "+t:"FormatException",r=this.b
if(typeof r=="string"){if(r.length>78)r=B.b.H(r,0,75)+"..."
return s+"\n"+r}else return s}}
A.d.prototype={
U(a,b){return A.eI(this,A.E(this).h("d.E"),b)},
gk(a){var t,s=this.gn(this)
for(t=0;s.l();)++t
return t},
gp(a){return!this.gn(this).l()},
gF(a){return!this.gp(this)},
A(a,b){var t,s
A.d4(b,"index")
t=this.gn(this)
for(s=b;t.l();){if(s===0)return t.gm();--s}throw A.b(A.d0(b,b-s,this,"index"))},
j(a){return A.eP(this,"(",")")}}
A.a3.prototype={
j(a){return"MapEntry("+A.r(this.a)+": "+A.r(this.b)+")"}}
A.aU.prototype={
gq(a){return A.j.prototype.gq.call(this,0)},
j(a){return"null"}}
A.j.prototype={$ij:1,
C(a,b){return this===b},
gq(a){return A.bC(this)},
j(a){return"Instance of '"+A.bD(this)+"'"},
gK(a){return A.he(this)},
toString(){return this.j(this)}}
A.a6.prototype={
gk(a){return this.a.length},
j(a){var t=this.a
return t.charCodeAt(0)==0?t:t},
$if_:1}
A.N.prototype={
saU(a){this.c=u.cl.a(a)}}
A.bX.prototype={}
A.cV.prototype={
$1(a){return A.e7(A.K(a))===this.a},
$S:0}
A.cW.prototype={
$1(a){u.d.a(a)
return a.b.length===0&&this.a.length>1&&a.a===this.b},
$S:8}
A.cQ.prototype={
$1(a){return B.b.J(A.K(a),"\u2029")},
$S:0}
A.cR.prototype={
$1(a){return A.K(a).length>20},
$S:0}
A.cS.prototype={
$1(a){return A.K(a).length},
$S:9}
A.cT.prototype={
$0(){var t=this,s=t.b,r=s.a,q=B.b.v(r.charCodeAt(0)==0?r:r)
s.a=""
if(q.length!==0){B.a.i(t.c,q)
B.a.i(t.d,t.a.a)}},
$S:4}
A.cz.prototype={
$1(a){return u.cM.a(a)!=null},
$S:10}
A.cA.prototype={
$2(a,b){return A.ak(a)+B.b.v(A.K(b)).length},
$S:11}
A.cB.prototype={
$2(a,b){var t=u.x
return B.d.u(t.a(a).b,t.a(b).b)},
$S:12}
A.cC.prototype={
$3(a,b,c){var t
A.ak(c)
t=A.c([],u.X)
return new A.N(a,A.ec(B.a.ar(this.a,b,c),b,t),t)},
$S:13}
A.m.prototype={
P(a){var t=this
return new A.m(Math.min(t.a,a.a),Math.min(t.b,a.b),Math.max(t.c,a.c),Math.max(t.d,a.d))},
j(a){var t=this
return"LRect("+B.c.Y(t.a,1)+", "+B.c.Y(t.b,1)+", "+B.c.Y(t.c,1)+", "+B.c.Y(t.d,1)+")"}}
A.q.prototype={}
A.bz.prototype={}
A.a4.prototype={}
A.cy.prototype={
$1(a){var t,s,r,q,p,o=A.c([],u.t)
for(t=this.a,s=a.b,r=this.b,q=0;q<t.length;++q){p=t[q]
if(s.test(p)){if(!(q<r.length))return A.e(r,q)
o.push(r[q])}}return o},
$S:14}
A.cU.prototype={
$0(){var t=this,s=t.b,r=s.a,q=A.y("[\\s\xa0]+",!0),p=B.b.v(A.aC(r.charCodeAt(0)==0?r:r,q," "))
if(p.length!==0&&t.a.a!=null){r=t.a.a
r.toString
B.a.i(t.c,new A.q(p,r,A.fY(t.d,t.e)))}s.a=""
t.a.a=null
B.a.am(t.e)
B.a.am(t.d)},
$S:4}
A.cr.prototype={
$2(a,b){var t=u.n
return B.c.u(t.a(a).b.b,t.a(b).b.b)},
$S:1}
A.cs.prototype={
$2(a,b){var t=u.o
return B.c.u(t.a(a).a,t.a(b).a)},
$S:15}
A.cI.prototype={
$2(a,b){var t,s,r,q,p,o,n,m,l,k,j,i,h,g,f=this
u.Y.a(a)
if(a.length<=1||b>60){B.a.i(f.a,a)
return}t=A.c([],u.u)
for(s=a.length,r=0;r<a.length;a.length===s||(0,A.l)(a),++r)t.push(a[r].b)
s=A.dZ(t,!0)
q=f.b
p=A.u(s)
o=p.h("A<1>")
n=A.ag(new A.A(s,p.h("n(1)").a(new A.cJ(q)),o),o.h("d.E"))
m=A.dZ(t,!1)
t=new A.cN()
l=t.$1(n)
s=A.u(m)
p=s.h("n(1)")
s=s.h("A<1>")
o=s.h("d.E")
k=A.ag(new A.A(m,p.a(new A.cK(q)),s),o)
j=t.$1(k)
k=new A.cM(a,q,f,b)
i=l!=null
if(i)h=j==null||j.b-j.a<q*2.5
else h=!1
if(h)if(k.$2(l,!0))return
if(j!=null&&k.$2(j,!1))return
if(i&&k.$2(l,!0))return
s=A.ag(new A.A(m,p.a(new A.cL(q)),s),o)
g=t.$1(s)
if(g!=null&&A.fD(a,q)&&k.$2(g,!1))return
B.a.i(f.a,a)},
$S:16}
A.cJ.prototype={
$1(a){u.o.a(a)
return a.b-a.a>=this.a*0.8},
$S:2}
A.cN.prototype={
$1(a){u.k.a(a)
return a.length===0?null:B.a.O(a,new A.cO())},
$S:17}
A.cO.prototype={
$2(a,b){var t=u.o
t.a(a)
t.a(b)
return b.b-b.a>a.b-a.a?b:a},
$S:18}
A.cK.prototype={
$1(a){u.o.a(a)
return a.b-a.a>=this.a*1.6},
$S:2}
A.cM.prototype={
$2(a,b){var t,s,r,q,p=this,o=(a.a+a.b)/2,n=u.E,m=A.c([],n),l=A.c([],n)
for(n=p.a,t=n.length,s=0;s<n.length;n.length===t||(0,A.l)(n),++s){r=n[s]
q=r.b
B.a.i((b?q.c:q.d)<=o?m:l,r)}if(m.length===0||l.length===0)return!1
if(b)n=A.e3(m)<3||A.e3(l)<3||!A.fm(l,p.b)
else n=!1
if(n)return!1
n=p.c
t=p.d+1
n.$2(m,t)
n.$2(l,t)
return!0},
$S:19}
A.cL.prototype={
$1(a){u.o.a(a)
return a.b-a.a>=this.a*0.25},
$S:2}
A.cF.prototype={
$2(a,b){var t=u.n,s=t.a(a).b
t=t.a(b).b
if(A.bg(s,t))return B.c.u(s.a,t.a)
return B.c.u(s.b+s.d,t.b+t.d)},
$S:1}
A.cG.prototype={
$1(a){return u.n.a(a).b},
$S:5}
A.cH.prototype={
$2(a,b){var t=u.R
return t.a(a).P(t.a(b))},
$S:6}
A.cu.prototype={
$1(a){var t
u.Y.a(a)
t=A.u(a)
return new A.ah(a,t.h("m(1)").a(new A.cv()),t.h("ah<1,m>")).O(0,new A.cw())},
$S:20}
A.cv.prototype={
$1(a){return u.n.a(a).b},
$S:5}
A.cw.prototype={
$2(a,b){var t=u.R
return t.a(a).P(t.a(b))},
$S:6}
A.cx.prototype={
$1(a){var t,s,r
u.Y.a(a)
t=A.c([],u.t)
for(s=a.length,r=0;r<a.length;a.length===s||(0,A.l)(a),++r)t.push(a[r].c)
return A.al(t)},
$S:21}
A.cn.prototype={
$2(a,b){var t=u.n
return B.c.u(t.a(a).b.b,t.a(b).b.b)},
$S:1}
A.co.prototype={
$1(a){return A.d9(a)-this.a<this.b*0.5},
$S:7}
A.cp.prototype={
$1(a){var t=A.d9(a)-this.a,s=this.b
return t>=s*0.5&&t<s*3.5},
$S:7}
A.ct.prototype={
$2(a,b){var t=u.R
return B.c.u(t.a(a).b,t.a(b).b)},
$S:22}
A.cP.prototype={
$1(a){return A.hn(A.K(a))},
$S:23};(function aliases(){var t=J.a2.prototype
t.av=t.j})();(function installTearOffs(){var t=hunkHelpers._static_2,s=hunkHelpers._static_1,r=hunkHelpers.installStaticTearOff
t(J,"fH","eT",24)
s(A,"h9","fw",25)
r(A,"hl",2,null,["$1$2","$2"],["e9",function(a,b){return A.e9(a,b,u.H)}],26,0)})();(function inheritance(){var t=hunkHelpers.mixin,s=hunkHelpers.inherit,r=hunkHelpers.inheritMany
s(A.j,null)
r(A.j,[A.d2,J.bt,A.aY,J.ac,A.d,A.aF,A.p,A.ca,A.J,A.aT,A.b2,A.S,A.b5,A.a5,A.D,A.cc,A.c6,A.I,A.c2,A.aQ,A.aP,A.aL,A.b7,A.bL,A.bH,A.bS,A.R,A.bN,A.ck,A.bQ,A.ai,A.O,A.bn,A.bp,A.ch,A.aZ,A.cf,A.aI,A.a3,A.aU,A.a6,A.N,A.bX,A.m,A.q,A.bz,A.a4])
r(J.bt,[J.bv,J.aK,J.au,J.as,J.a1])
r(J.au,[J.a2,J.i])
r(J.a2,[J.c8,J.Z,J.aM])
s(J.bu,A.aY)
s(J.bZ,J.i)
r(J.as,[J.aJ,J.bw])
r(A.d,[A.a7,A.k,A.aS,A.A,A.bK,A.bR])
r(A.a7,[A.ad,A.bf])
s(A.b4,A.ad)
s(A.b3,A.bf)
s(A.T,A.b3)
r(A.p,[A.bA,A.b0,A.bx,A.bJ,A.bE,A.bM,A.aN,A.bj,A.a0,A.b1,A.bF,A.bo])
r(A.k,[A.z,A.af,A.aO])
r(A.z,[A.b_,A.ah,A.bP])
r(A.S,[A.aw,A.ax,A.ay])
s(A.a8,A.aw)
s(A.b8,A.ax)
s(A.b9,A.ay)
r(A.a5,[A.aG,A.ba])
s(A.aH,A.aG)
r(A.D,[A.bs,A.bl,A.bm,A.bI,A.cV,A.cW,A.cQ,A.cR,A.cS,A.cz,A.cC,A.cy,A.cJ,A.cN,A.cK,A.cL,A.cG,A.cu,A.cv,A.cx,A.co,A.cp,A.cP])
s(A.ar,A.bs)
s(A.aV,A.b0)
r(A.bI,[A.bG,A.aq])
r(A.I,[A.ae,A.bO])
s(A.az,A.bM)
s(A.b6,A.ba)
r(A.bm,[A.c5,A.ci,A.cA,A.cB,A.cr,A.cs,A.cI,A.cO,A.cM,A.cF,A.cH,A.cw,A.cn,A.ct])
s(A.by,A.aN)
s(A.c_,A.bn)
r(A.bp,[A.c1,A.c0])
s(A.cg,A.ch)
r(A.a0,[A.aW,A.br])
r(A.bl,[A.cT,A.cU])
t(A.bf,A.O)})()
var v={G:typeof self!="undefined"?self:globalThis,typeUniverse:{eC:new Map(),tR:{},eT:{},tPV:{},sEA:[]},mangledGlobalNames:{h:"int",a:"double",B:"num",f:"String",n:"bool",aU:"Null",o:"List",j:"Object",aR:"Map",at:"JSObject"},mangledNames:{},types:["n(f)","h(q,q)","n(+(a,a))","~(j?,j?)","~()","m(q)","m(m,m)","n(a)","n(N)","h(f)","n(a4?)","h(h,f)","h(+(f,h),+(f,h))","N(f,h,h)","o<a>(c9)","h(+(a,a),+(a,a))","~(o<q>,h)","+(a,a)?(o<+(a,a)>)","+(a,a)(+(a,a),+(a,a))","n(+(a,a),n)","m(o<q>)","a(o<q>)","h(m,m)","f(f)","h(@,@)","@(@)","0^(0^,0^)<B>"],arrayRti:Symbol("$ti"),rttc:{"2;":(a,b)=>c=>c instanceof A.a8&&a.b(c.a)&&b.b(c.b),"3;":(a,b,c)=>d=>d instanceof A.b8&&a.b(d.a)&&b.b(d.b)&&c.b(d.c),"4;":a=>b=>b instanceof A.b9&&A.hm(a,b.a)}}
A.fj(v.typeUniverse,JSON.parse('{"aM":"a2","c8":"a2","Z":"a2","bv":{"n":[],"X":[]},"aK":{"X":[]},"au":{"at":[]},"a2":{"at":[]},"i":{"o":["1"],"k":["1"],"at":[],"d":["1"]},"bu":{"aY":[]},"bZ":{"i":["1"],"o":["1"],"k":["1"],"at":[],"d":["1"]},"ac":{"t":["1"]},"as":{"a":[],"B":[],"U":["B"]},"aJ":{"a":[],"h":[],"B":[],"U":["B"],"X":[]},"bw":{"a":[],"B":[],"U":["B"],"X":[]},"a1":{"f":[],"U":["f"],"bB":[],"X":[]},"a7":{"d":["2"]},"aF":{"t":["2"]},"ad":{"a7":["1","2"],"d":["2"],"d.E":"2"},"b4":{"ad":["1","2"],"a7":["1","2"],"k":["2"],"d":["2"],"d.E":"2"},"b3":{"O":["2"],"o":["2"],"a7":["1","2"],"k":["2"],"d":["2"]},"T":{"b3":["1","2"],"O":["2"],"o":["2"],"a7":["1","2"],"k":["2"],"d":["2"],"O.E":"2","d.E":"2"},"bA":{"p":[]},"k":{"d":["1"]},"z":{"k":["1"],"d":["1"]},"b_":{"z":["1"],"k":["1"],"d":["1"],"d.E":"1","z.E":"1"},"J":{"t":["1"]},"aS":{"d":["2"],"d.E":"2"},"aT":{"t":["2"]},"ah":{"z":["2"],"k":["2"],"d":["2"],"d.E":"2","z.E":"2"},"A":{"d":["1"],"d.E":"1"},"b2":{"t":["1"]},"a8":{"aw":[],"S":[]},"b8":{"ax":[],"S":[]},"b9":{"ay":[],"S":[]},"b5":{"t":["1"]},"aG":{"a5":["1"],"k":["1"],"d":["1"]},"aH":{"aG":["1"],"a5":["1"],"k":["1"],"d":["1"]},"bs":{"D":[],"V":[]},"ar":{"D":[],"V":[]},"aV":{"p":[]},"bx":{"p":[]},"bJ":{"p":[]},"D":{"V":[]},"bl":{"D":[],"V":[]},"bm":{"D":[],"V":[]},"bI":{"D":[],"V":[]},"bG":{"D":[],"V":[]},"aq":{"D":[],"V":[]},"bE":{"p":[]},"ae":{"I":["1","2"],"dB":["1","2"],"aR":["1","2"],"I.K":"1","I.V":"2"},"af":{"k":["1"],"d":["1"],"d.E":"1"},"aQ":{"t":["1"]},"aO":{"k":["a3<1,2>"],"d":["a3<1,2>"],"d.E":"a3<1,2>"},"aP":{"t":["a3<1,2>"]},"aw":{"S":[]},"ax":{"S":[]},"ay":{"S":[]},"aL":{"c9":[],"bB":[]},"b7":{"aX":[],"av":[]},"bK":{"d":["aX"],"d.E":"aX"},"bL":{"t":["aX"]},"bH":{"av":[]},"bR":{"d":["av"],"d.E":"av"},"bS":{"t":["av"]},"bM":{"p":[]},"az":{"p":[]},"b6":{"a5":["1"],"k":["1"],"d":["1"]},"ai":{"t":["1"]},"I":{"aR":["1","2"]},"a5":{"k":["1"],"d":["1"]},"ba":{"a5":["1"],"k":["1"],"d":["1"]},"bO":{"I":["f","@"],"aR":["f","@"],"I.K":"f","I.V":"@"},"bP":{"z":["f"],"k":["f"],"d":["f"],"d.E":"f","z.E":"f"},"aN":{"p":[]},"by":{"p":[]},"a":{"B":[],"U":["B"]},"h":{"B":[],"U":["B"]},"o":{"k":["1"],"d":["1"]},"B":{"U":["B"]},"c9":{"bB":[]},"aX":{"av":[]},"f":{"U":["f"],"bB":[]},"bj":{"p":[]},"b0":{"p":[]},"a0":{"p":[]},"aW":{"p":[]},"br":{"p":[]},"b1":{"p":[]},"bF":{"p":[]},"bo":{"p":[]},"aZ":{"p":[]},"a6":{"f_":[]}}'))
A.fi(v.typeUniverse,JSON.parse('{"bf":2,"ba":1,"bn":2,"bp":2}'))
var u=(function rtii(){var t=A.bU
return{W:t("U<@>"),_:t("k<@>"),C:t("p"),Z:t("V"),d:t("N"),a:t("d<@>"),p:t("i<N>"),V:t("i<bz>"),u:t("i<m>"),E:t("i<q>"),c:t("i<o<q>>"),J:t("i<aR<f,j>>"),f:t("i<j>"),q:t("i<+(f,h)>"),G:t("i<+(a,a)>"),h:t("i<+(a,a,m)>"),D:t("i<+(a,a,a,a)>"),s:t("i<f>"),t:t("i<a>"),b:t("i<@>"),X:t("i<h>"),e:t("i<a4?>"),T:t("aK"),m:t("at"),g:t("aM"),R:t("m"),w:t("m(q)"),n:t("q"),Y:t("o<q>"),k:t("o<+(a,a)>"),j:t("o<@>"),l:t("aR<f,@>"),A:t("aS<f,h>"),r:t("ah<q,m>"),P:t("aU"),K:t("j"),B:t("hA"),F:t("+()"),x:t("+(f,h)"),o:t("+(a,a)"),a0:t("aX"),N:t("f"),bW:t("X"),cr:t("Z"),U:t("A<f>"),v:t("A<a>"),y:t("n"),Q:t("n(f)"),ax:t("n(a)"),i:t("a"),S:t("h"),bv:t("h(f)"),bc:t("dw<aU>?"),z:t("at?"),L:t("o<@>?"),cl:t("o<h>?"),O:t("j?"),cM:t("a4?"),aD:t("f?"),M:t("bQ?"),cG:t("n?"),I:t("a?"),a3:t("h?"),ae:t("B?"),H:t("B"),cQ:t("~(f,@)")}})();(function constants(){var t=hunkHelpers.makeConstList
B.l=J.bt.prototype
B.a=J.i.prototype
B.d=J.aJ.prototype
B.c=J.as.prototype
B.b=J.a1.prototype
B.m=J.au.prototype
B.i=new A.ar(A.hl(),A.bU("ar<a>"))
B.j=function getTagFallback(o) {
  var s = Object.prototype.toString.call(o);
  return s.substring(8, s.length - 1);
}
B.f=new A.c_()
B.e=new A.ca()
B.k=new A.aI("This PDF has no text layer (it looks like scanned pages), so it cannot be read aloud yet.",null)
B.n=new A.c0(null)
B.o=new A.c1(null)
B.q=t([],u.V)
B.p=t([],u.X)
B.h=t([],u.b)
B.r={}
B.u=new A.aH(B.r,0,A.bU("aH<f>"))
B.t=A.hx("j")})();(function staticFields(){$.L=A.c([],u.f)
$.dE=null
$.ds=null
$.dr=null
$.cj=A.c([],A.bU("i<o<j>?>"))})();(function lazyInitializers(){var t=hunkHelpers.lazyFinal
t($,"hz","eh",()=>A.e6("_$dart_dartClosure"))
t($,"hy","dl",()=>A.e6("_$dart_dartClosure_dartJSInterop"))
t($,"hT","ey",()=>A.c([new J.bu()],A.bU("i<aY>")))
t($,"hB","ei",()=>A.Y(A.cd({
toString:function(){return"$receiver$"}})))
t($,"hC","ej",()=>A.Y(A.cd({$method$:null,
toString:function(){return"$receiver$"}})))
t($,"hD","ek",()=>A.Y(A.cd(null)))
t($,"hE","el",()=>A.Y(function(){var $argumentsExpr$="$arguments$"
try{null.$method$($argumentsExpr$)}catch(s){return s.message}}()))
t($,"hH","eo",()=>A.Y(A.cd(void 0)))
t($,"hI","ep",()=>A.Y(function(){var $argumentsExpr$="$arguments$"
try{(void 0).$method$($argumentsExpr$)}catch(s){return s.message}}()))
t($,"hG","en",()=>A.Y(A.dJ(null)))
t($,"hF","em",()=>A.Y(function(){try{null.$method$}catch(s){return s.message}}()))
t($,"hK","er",()=>A.Y(A.dJ(void 0)))
t($,"hJ","eq",()=>A.Y(function(){try{(void 0).$method$}catch(s){return s.message}}()))
t($,"hP","bW",()=>A.eb(B.t))
t($,"hM","et",()=>A.y("^(chapter|ch\\.|prologue|epilogue|part|book|volume|\u7b2c)\\s*[\\divxlc\u96f6\u4e00\u4e8c\u4e09\u56db\u4e94\u516d\u4e03\u516b\u4e5d\u5341\u767e\u5343]*",!1))
t($,"hU","dn",()=>A.y('[.!?\u2026:;"\u201d\u2019)\\]]$',!0))
t($,"hQ","ew",()=>A.y("^(chapter|ch\\.|prologue|epilogue|part|book|volume|interlude|afterword|\u7b2c)(\\s+[\\w\u4e00\u4e8c\u4e09\u56db\u4e94\u516d\u4e03\u516b\u4e5d\u5341\u767e]+)?\\s*([:.\\-\u2013\u2014]\\s*.{0,60})?$",!1))
t($,"hV","ez",()=>A.y('[.!?\u2026:;"\u201d\u2019)\\]}]$',!0))
t($,"hO","ev",()=>A.y("^(\\d{1,4}\\s*[|\u2022\xb7]\\s*.{1,40}|.{1,40}\\s*[|\u2022\xb7]\\s*\\d{1,4}|(page\\s*)?\\d{1,4}(\\s*(of|/)\\s*\\d+)?)$",!1))
t($,"hL","es",()=>A.y("[A-Zbdfhkl0-9]",!0))
t($,"hN","eu",()=>A.y("[gjpqy]",!0))
t($,"hS","ex",()=>A.y("[a-z]",!0))
t($,"hR","dm",()=>A.y("^(#{1,3}) ",!0))})();(function nativeSupport(){!function(){var t=function(a){var n={}
n[a]=1
return Object.keys(hunkHelpers.convertToFastObject(n))[0]}
v.getIsolateTag=function(a){return t("___dart_"+a+v.isolateTag)}
var s="___dart_isolate_tags_"
var r=Object[s]||(Object[s]=Object.create(null))
var q="_ZxYxX"
for(var p=0;;p++){var o=t(q+"_"+p+"_")
if(!(o in r)){r[o]=1
v.isolateTag=o
break}}}()
hunkHelpers.setOrUpdateInterceptorsByTag({})
hunkHelpers.setOrUpdateLeafTags({})})()
Function.prototype.$0=function(){return this()}
Function.prototype.$1=function(a){return this(a)}
Function.prototype.$1$0=function(){return this()}
Function.prototype.$2=function(a,b){return this(a,b)}
Function.prototype.$3=function(a,b,c){return this(a,b,c)}
Function.prototype.$4=function(a,b,c,d){return this(a,b,c,d)}
convertAllToFastObject(w)
convertToFastObject($);(function(a){if(typeof document==="undefined"){a(null)
return}if(typeof document.currentScript!="undefined"){a(document.currentScript)
return}var t=document.scripts
function onLoad(b){for(var r=0;r<t.length;++r){t[r].removeEventListener("load",onLoad,false)}a(b.target)}for(var s=0;s<t.length;++s){t[s].addEventListener("load",onLoad,false)}})(function(a){v.currentScript=a
var t=A.hk
if(typeof dartMainRunner==="function"){dartMainRunner(t,[])}else{t([])}})})()
//# sourceMappingURL=pdfbook.js.map
