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
if(a[b]!==t){A.hF(b)}a[b]=s}var r=a[b]
a[c]=function(){return r}
return r}}function makeConstList(a,b){if(b!=null)A.b(a,b)
a.$flags=7
return a}function convertToFastObject(a){function t(){}t.prototype=a
new t()
return a}function convertAllToFastObject(a){for(var t=0;t<a.length;++t){convertToFastObject(a[t])}}var y=0
function instanceTearOffGetter(a,b){var t=null
return a?function(c){if(t===null)t=A.dl(b)
return new t(c,this)}:function(){if(t===null)t=A.dl(b)
return new t(this,null)}}function staticTearOffGetter(a){var t=null
return function(){if(t===null)t=A.dl(a).prototype
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
f_(a,b){if(a<0||a>4294967295)throw A.c(A.R(a,0,4294967295,"length",null))
return J.f1(new Array(a),b)},
f0(a,b){if(a<0)throw A.c(A.d5("Length must be a non-negative integer: "+a))
return A.b(new Array(a),b.h("i<0>"))},
f1(a,b){var t=A.b(a,b.h("i<0>"))
t.$flags=1
return t},
f2(a,b){var t=u.W
return J.eL(t.a(a),t.a(b))},
dD(a){if(a<256)switch(a){case 9:case 10:case 11:case 12:case 13:case 32:case 133:case 160:return!0
default:return!1}switch(a){case 5760:case 8192:case 8193:case 8194:case 8195:case 8196:case 8197:case 8198:case 8199:case 8200:case 8201:case 8202:case 8232:case 8233:case 8239:case 8287:case 12288:case 65279:return!0
default:return!1}},
f3(a,b){var t,s
for(t=a.length;b<t;){s=a.charCodeAt(b)
if(s!==32&&s!==13&&!J.dD(s))break;++b}return b},
dE(a,b){var t,s,r
for(t=a.length;b>0;b=s){s=b-1
if(!(s<t))return A.f(a,s)
r=a.charCodeAt(s)
if(r!==32&&r!==13&&!J.dD(r))break}return b},
as(a){if(typeof a=="number"){if(Math.floor(a)==a)return J.aN.prototype
return J.bA.prototype}if(typeof a=="string")return J.a6.prototype
if(a==null)return J.aO.prototype
if(typeof a=="boolean")return J.bz.prototype
if(Array.isArray(a))return J.i.prototype
if(typeof a=="function")return J.aQ.prototype
if(typeof a=="object"){if(a instanceof A.k){return a}else{return J.az.prototype}}if(!(a instanceof A.k))return J.a3.prototype
return a},
cH(a){if(a==null)return a
if(Array.isArray(a))return J.i.prototype
if(!(a instanceof A.k))return J.a3.prototype
return a},
bX(a){if(typeof a=="string")return J.a6.prototype
if(a==null)return a
if(Array.isArray(a))return J.i.prototype
if(!(a instanceof A.k))return J.a3.prototype
return a},
hm(a){if(typeof a=="number")return J.ax.prototype
if(typeof a=="string")return J.a6.prototype
if(a==null)return a
if(!(a instanceof A.k))return J.a3.prototype
return a},
ec(a){if(typeof a=="string")return J.a6.prototype
if(a==null)return a
if(!(a instanceof A.k))return J.a3.prototype
return a},
ag(a,b){if(a==null)return b==null
if(typeof a!="object")return b!=null&&a===b
return J.as(a).C(a,b)},
r(a,b){if(typeof b==="number")if(Array.isArray(a)||typeof a=="string")if(b>>>0===b&&b<a.length)return a[b]
return J.bX(a).D(a,b)},
X(a,b){return J.cH(a).i(a,b)},
eK(a,b){return J.ec(a).am(a,b)},
bl(a,b){return J.cH(a).V(a,b)},
eL(a,b){return J.hm(a).t(a,b)},
dv(a,b){return J.cH(a).u(a,b)},
K(a){return J.as(a).gq(a)},
eM(a){return J.bX(a).gp(a)},
eN(a){return J.bX(a).gG(a)},
bm(a){return J.cH(a).gn(a)},
L(a){return J.bX(a).gk(a)},
eO(a){return J.as(a).gL(a)},
aI(a){return J.as(a).j(a)},
eP(a){return J.ec(a).v(a)},
bx:function bx(){},
bz:function bz(){},
aO:function aO(){},
az:function az(){},
a7:function a7(){},
ca:function ca(){},
a3:function a3(){},
aQ:function aQ(){},
i:function i(a){this.$ti=a},
by:function by(){},
c0:function c0(a){this.$ti=a},
ah:function ah(a,b,c){var _=this
_.a=a
_.b=b
_.c=0
_.d=null
_.$ti=c},
ax:function ax(){},
aN:function aN(){},
bA:function bA(){},
a6:function a6(){}},A={d9:function d9(){},
eS(a,b,c){if(u._.b(a))return new A.b7(a,b.h("@<0>").E(c).h("b7<1,2>"))
return new A.ai(a,b.h("@<0>").E(c).h("ai<1,2>"))},
a0(a,b){a=a+b&536870911
a=a+((a&524287)<<10)&536870911
return a^a>>>6},
cd(a){a=a+((a&67108863)<<3)&536870911
a^=a>>>11
return a+((a&16383)<<15)&536870911},
dq(a){var t,s
for(t=$.P.length,s=0;s<t;++s)if(a===$.P[s])return!0
return!1},
fa(a,b,c,d){A.bH(b,"start")
if(c!=null){A.bH(c,"end")
if(b>c)A.d4(A.R(b,0,c,"start",null))}return new A.ao(a,b,c,d.h("ao<0>"))},
c_(){return new A.bJ("No element")},
ac:function ac(){},
aJ:function aJ(a,b){this.a=a
this.$ti=b},
ai:function ai(a,b){this.a=a
this.$ti=b},
b7:function b7(a,b){this.a=a
this.$ti=b},
b6:function b6(){},
Y:function Y(a,b){this.a=a
this.$ti=b},
bD:function bD(a){this.a=a},
cc:function cc(){},
m:function m(){},
y:function y(){},
ao:function ao(a,b,c,d){var _=this
_.a=a
_.b=b
_.c=c
_.$ti=d},
x:function x(a,b,c){var _=this
_.a=a
_.b=b
_.c=0
_.d=null
_.$ti=c},
aW:function aW(a,b,c){this.a=a
this.b=b
this.$ti=c},
aX:function aX(a,b,c){var _=this
_.a=null
_.b=a
_.c=b
_.$ti=c},
N:function N(a,b,c){this.a=a
this.b=b
this.$ti=c},
D:function D(a,b,c){this.a=a
this.b=b
this.$ti=c},
b5:function b5(a,b,c){this.a=a
this.b=b
this.$ti=c},
bi:function bi(){},
eY(){throw A.c(A.cg("Cannot modify constant Set"))},
ep(a){var t=A.eo(a)
if(t!=null)return t
return"minified:"+a},
n(a){var t
if(typeof a=="string")return a
if(typeof a=="number"){if(a!==0)return""+a}else if(!0===a)return"true"
else if(!1===a)return"false"
else if(a==null)return"null"
t=J.aI(a)
return t},
bF(a){var t,s=$.dK
if(s==null)s=$.dK=Symbol("identityHashCode")
t=a[s]
if(t==null){t=Math.random()*0x3fffffff|0
a[s]=t}return t},
bG(a){var t,s,r,q
if(a instanceof A.k)return A.J(A.bk(a),null)
t=J.as(a)
if(t===B.m||t===B.n||u.cr.b(a)){s=B.k(a)
if(s!=="Object"&&s!=="")return s
r=a.constructor
if(typeof r=="function"){q=r.name
if(typeof q=="string"&&q!=="Object"&&q!=="")return q}}return A.J(A.bk(a),null)},
dL(a){var t,s,r
if(a==null||typeof a=="number"||A.dj(a))return J.aI(a)
if(typeof a=="string")return JSON.stringify(a)
if(a instanceof A.F)return a.j(0)
if(a instanceof A.U)return a.al(!0)
t=$.eI()
for(s=0;s<1;++s){r=t[s].b0(a)
if(r!=null)return r}return"Instance of '"+A.bG(a)+"'"},
B(a){var t
if(a<=65535)return String.fromCharCode(a)
if(a<=1114111){t=a-65536
return String.fromCharCode((B.d.ak(t,10)|55296)>>>0,t&1023|56320)}throw A.c(A.R(a,0,1114111,null,null))},
f(a,b){if(a==null)J.L(a)
throw A.c(A.dm(a,b))},
dm(a,b){var t,s="index"
if(!A.e6(b))return new A.a5(!0,b,s,null)
t=J.L(a)
if(b<0||b>=t)return A.d7(b,t,a,s)
return A.dM(b,s)},
he(a){return new A.a5(!0,a,null,null)},
c(a){return A.A(a,new Error())},
A(a,b){var t
if(a==null)a=new A.b3()
b.dartException=a
t=A.hG
if("defineProperty" in Object){Object.defineProperty(b,"message",{get:t})
b.name=""}else b.toString=t
return b},
hG(){return J.aI(this.dartException)},
d4(a,b){throw A.A(a,b==null?new Error():b)},
av(a,b,c){var t
if(b==null)b=0
if(c==null)c=0
t=Error()
A.d4(A.fH(a,b,c),t)},
fH(a,b,c){var t,s,r,q,p,o,n,m,l
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
return new A.b4("'"+t+"': Cannot "+p+" "+m+l+o)},
j(a){throw A.c(A.G(a))},
a2(a){var t,s,r,q,p,o
a=A.em(a.replace(String({}),"$receiver$"))
t=a.match(/\\\$[a-zA-Z]+\\\$/g)
if(t==null)t=A.b([],u.s)
s=t.indexOf("\\$arguments\\$")
r=t.indexOf("\\$argumentsExpr\\$")
q=t.indexOf("\\$expr\\$")
p=t.indexOf("\\$method\\$")
o=t.indexOf("\\$receiver\\$")
return new A.ce(a.replace(new RegExp("\\\\\\$arguments\\\\\\$","g"),"((?:x|[^x])*)").replace(new RegExp("\\\\\\$argumentsExpr\\\\\\$","g"),"((?:x|[^x])*)").replace(new RegExp("\\\\\\$expr\\\\\\$","g"),"((?:x|[^x])*)").replace(new RegExp("\\\\\\$method\\\\\\$","g"),"((?:x|[^x])*)").replace(new RegExp("\\\\\\$receiver\\\\\\$","g"),"((?:x|[^x])*)"),s,r,q,p,o)},
cf(a){return function($expr$){var $argumentsExpr$="$arguments$"
try{$expr$.$method$($argumentsExpr$)}catch(t){return t.message}}(a)},
dP(a){return function($expr$){try{$expr$.$method$}catch(t){return t.message}}(a)},
da(a,b){var t=b==null,s=t?null:b.method
return new A.bB(a,s,t?null:b.receiver)},
dr(a){if(a==null)return new A.c8(a)
if(typeof a!=="object")return a
if("dartException" in a)return A.au(a,a.dartException)
return A.hc(a)},
au(a,b){if(u.C.b(b))if(b.$thrownJsError==null)b.$thrownJsError=a
return b},
hc(a){var t,s,r,q,p,o,n,m,l,k,j,i,h
if(!("message" in a))return a
t=a.message
if("number" in a&&typeof a.number=="number"){s=a.number
r=s&65535
if((B.d.ak(s,16)&8191)===10)switch(r){case 438:return A.au(a,A.da(A.n(t)+" (Error "+r+")",null))
case 445:case 5007:A.n(t)
return A.au(a,new A.aZ())}}if(a instanceof TypeError){q=$.er()
p=$.es()
o=$.et()
n=$.eu()
m=$.ex()
l=$.ey()
k=$.ew()
$.ev()
j=$.eA()
i=$.ez()
h=q.B(t)
if(h!=null)return A.au(a,A.da(A.O(t),h))
else{h=p.B(t)
if(h!=null){h.method="call"
return A.au(a,A.da(A.O(t),h))}else if(o.B(t)!=null||n.B(t)!=null||m.B(t)!=null||l.B(t)!=null||k.B(t)!=null||n.B(t)!=null||j.B(t)!=null||i.B(t)!=null){A.O(t)
return A.au(a,new A.aZ())}}return A.au(a,new A.bN(typeof t=="string"?t:""))}if(a instanceof RangeError){if(typeof t=="string"&&t.indexOf("call stack")!==-1)return new A.b2()
t=function(b){try{return String(b)}catch(g){}return null}(a)
return A.au(a,new A.a5(!1,null,null,typeof t=="string"?t.replace(/^RangeError:\s*/,""):t))}if(typeof InternalError=="function"&&a instanceof InternalError)if(typeof t=="string"&&t==="too much recursion")return new A.b2()
return a},
ek(a){if(a==null)return J.K(a)
if(typeof a=="object")return A.bF(a)
return J.K(a)},
hl(a,b){var t,s,r,q=a.length
for(t=0;t<q;t=r){s=t+1
r=s+1
b.A(0,a[t],a[s])}return b},
fS(a,b,c,d,e,f){u.Z.a(a)
switch(A.ar(b)){case 0:return a.$0()
case 1:return a.$1(c)
case 2:return a.$2(c,d)
case 3:return a.$3(c,d,e)
case 4:return a.$4(c,d,e,f)}throw A.c(new A.ch("Unsupported number of arguments for wrapped closure"))},
hg(a,b){var t=a.$identity
if(!!t)return t
t=A.hh(a,b)
a.$identity=t
return t},
hh(a,b){var t
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
return function(c,d,e){return function(f,g,h,i){return e(c,d,f,g,h,i)}}(a,b,A.fS)},
eX(a1){var t,s,r,q,p,o,n,m,l,k,j=a1.co,i=a1.iS,h=a1.iI,g=a1.nDA,f=a1.aI,e=a1.fs,d=a1.cs,c=e[0],b=d[0],a=j[c],a0=a1.fT
a0.toString
t=i?Object.create(new A.bK().constructor.prototype):Object.create(new A.aw(null,null).constructor.prototype)
t.$initialize=t.constructor
s=i?function static_tear_off(){this.$initialize()}:function tear_off(a2,a3){this.$initialize(a2,a3)}
t.constructor=s
s.prototype=t
t.$_name=c
t.$_target=a
r=!i
if(r)q=A.dA(c,a,h,g)
else{t.$static_name=c
q=a}t.$S=A.eT(a0,i,h)
t[b]=q
for(p=q,o=1;o<e.length;++o){n=e[o]
if(typeof n=="string"){m=j[n]
l=n
n=m}else l=""
k=d[o]
if(k!=null){if(r)n=A.dA(l,n,h,g)
t[k]=n}if(o===f)p=n}t.$C=p
t.$R=a1.rC
t.$D=a1.dV
return s},
eT(a,b,c){if(typeof a=="number")return a
if(typeof a=="string"){if(b)throw A.c("Cannot compute signature for static tearoff.")
return function(d,e){return function(){return e(this,d)}}(a,A.eQ)}throw A.c("Error in functionType of tearoff")},
eU(a,b,c,d){var t=A.dz
switch(b?-1:a){case 0:return function(e,f){return function(){return f(this)[e]()}}(c,t)
case 1:return function(e,f){return function(g){return f(this)[e](g)}}(c,t)
case 2:return function(e,f){return function(g,h){return f(this)[e](g,h)}}(c,t)
case 3:return function(e,f){return function(g,h,i){return f(this)[e](g,h,i)}}(c,t)
case 4:return function(e,f){return function(g,h,i,j){return f(this)[e](g,h,i,j)}}(c,t)
case 5:return function(e,f){return function(g,h,i,j,k){return f(this)[e](g,h,i,j,k)}}(c,t)
default:return function(e,f){return function(){return e.apply(f(this),arguments)}}(d,t)}},
dA(a,b,c,d){if(c)return A.eW(a,b,d)
return A.eU(b.length,d,a,b)},
eV(a,b,c,d){var t=A.dz,s=A.eR
switch(b?-1:a){case 0:throw A.c(new A.bI("Intercepted function with no arguments."))
case 1:return function(e,f,g){return function(){return f(this)[e](g(this))}}(c,s,t)
case 2:return function(e,f,g){return function(h){return f(this)[e](g(this),h)}}(c,s,t)
case 3:return function(e,f,g){return function(h,i){return f(this)[e](g(this),h,i)}}(c,s,t)
case 4:return function(e,f,g){return function(h,i,j){return f(this)[e](g(this),h,i,j)}}(c,s,t)
case 5:return function(e,f,g){return function(h,i,j,k){return f(this)[e](g(this),h,i,j,k)}}(c,s,t)
case 6:return function(e,f,g){return function(h,i,j,k,l){return f(this)[e](g(this),h,i,j,k,l)}}(c,s,t)
default:return function(e,f,g){return function(){var r=[g(this)]
Array.prototype.push.apply(r,arguments)
return e.apply(f(this),r)}}(d,s,t)}},
eW(a,b,c){var t,s
if($.dx==null)$.dx=A.dw("interceptor")
if($.dy==null)$.dy=A.dw("receiver")
t=b.length
s=A.eV(t,c,a,b)
return s},
dl(a){return A.eX(a)},
eQ(a,b){return A.bh(v.typeUniverse,A.bk(a.a),b)},
dz(a){return a.a},
eR(a){return a.b},
dw(a){var t,s,r,q=new A.aw("receiver","interceptor"),p=Object.getOwnPropertyNames(q)
p.$flags=1
t=p
for(p=t.length,s=0;s<p;++s){r=t[s]
if(q[r]===a)return r}throw A.c(A.d5("Field name "+a+" not found."))},
ed(a){return v.getIsolateTag(a)},
fl(a,b){var t,s
for(t=0;t<a.length;++t){s=a[t]
if(!(t<b.length))return A.f(b,t)
if(!J.ag(s,b[t]))return!1}return!0},
hj(a,b){var t=b.length,s=v.rttc[""+t+";"+a]
if(s==null)return null
if(t===0)return s
if(t===s.length)return s.apply(null,b)
return s(b)},
dF(a,b,c,d,e,f){var t=b?"m":"",s=c?"":"i",r=d?"u":"",q=e?"s":"",p=function(g,h){try{return new RegExp(g,h)}catch(o){return o}}(a,t+s+r+q+f)
if(p instanceof RegExp)return p
throw A.c(A.dB("Illegal RegExp pattern ("+String(p)+")",a))},
hA(a,b,c){var t=a.indexOf(b,c)
return t>=0},
dn(a){if(a.indexOf("$",0)>=0)return a.replace(/\$/g,"$$$$")
return a},
hD(a,b,c,d){var t=b.ag(a,d)
if(t==null)return a
return A.hE(a,t.b.index,t.gW(),c)},
em(a){if(/[[\]{}()*+?.\\^$|]/.test(a))return a.replace(/[[\]{}()*+?.\\^$|]/g,"\\$&")
return a},
aH(a,b,c){var t
if(typeof b=="string")return A.hC(a,b,c)
if(b instanceof A.aP){t=b.gai()
t.lastIndex=0
return a.replace(t,A.dn(c))}return A.hB(a,b,c)},
hB(a,b,c){var t,s,r,q
for(t=J.eK(b,a),t=t.gn(t),s=0,r="";t.l();){q=t.gm()
r=r+a.substring(s,q.gad())+c
s=q.gW()}t=r+a.substring(s)
return t.charCodeAt(0)==0?t:t},
hC(a,b,c){var t,s,r
if(b===""){if(a==="")return c
t=a.length
for(s=c,r=0;r<t;++r)s=s+a[r]+c
return s.charCodeAt(0)==0?s:s}if(a.indexOf(b,0)<0)return a
if(a.length<500||c.indexOf("$",0)>=0)return a.split(b).join(c)
return a.replace(new RegExp(A.em(b),"g"),A.dn(c))},
en(a,b,c,d){return d===0?a.replace(b.b,A.dn(c)):A.hD(a,b,c,d)},
hE(a,b,c,d){return a.substring(0,b)+d+a.substring(c)},
ad:function ad(a,b){this.a=a
this.b=b},
bb:function bb(a,b,c){this.a=a
this.b=b
this.c=c},
bc:function bc(a){this.a=a},
b8:function b8(a,b,c){var _=this
_.a=a
_.b=b
_.c=0
_.d=null
_.$ti=c},
aK:function aK(){},
aL:function aL(a,b,c){this.a=a
this.b=b
this.$ti=c},
bw:function bw(){},
aj:function aj(a,b){this.a=a
this.$ti=b},
b1:function b1(){},
ce:function ce(a,b,c,d,e,f){var _=this
_.a=a
_.b=b
_.c=c
_.d=d
_.e=e
_.f=f},
aZ:function aZ(){},
bB:function bB(a,b,c){this.a=a
this.b=b
this.c=c},
bN:function bN(a){this.a=a},
c8:function c8(a){this.a=a},
F:function F(){},
bp:function bp(){},
bq:function bq(){},
bM:function bM(){},
bK:function bK(){},
aw:function aw(a,b){this.a=a
this.b=b},
bI:function bI(a){this.a=a},
ak:function ak(a){var _=this
_.a=0
_.f=_.e=_.d=_.c=_.b=null
_.r=0
_.$ti=a},
c4:function c4(a,b){this.a=a
this.b=b
this.c=null},
am:function am(a,b){this.a=a
this.$ti=b},
aU:function aU(a,b,c,d){var _=this
_.a=a
_.b=b
_.c=c
_.d=null
_.$ti=d},
aS:function aS(a,b){this.a=a
this.$ti=b},
aT:function aT(a,b,c,d){var _=this
_.a=a
_.b=b
_.c=c
_.d=null
_.$ti=d},
U:function U(){},
aB:function aB(){},
aC:function aC(){},
aD:function aD(){},
aP:function aP(a,b){var _=this
_.a=a
_.b=b
_.e=_.c=null},
ba:function ba(a){this.b=a},
bO:function bO(a,b,c){this.a=a
this.b=b
this.c=c},
bP:function bP(a,b,c){var _=this
_.a=a
_.b=b
_.c=c
_.d=null},
bL:function bL(a,b){this.a=a
this.c=b},
bV:function bV(a,b,c){this.a=a
this.b=b
this.c=c},
bW:function bW(a,b,c){var _=this
_.a=a
_.b=b
_.c=c
_.d=null},
db(a,b){var t=b.c
return t==null?b.c=A.bf(a,"dC",[b.x]):t},
dN(a){var t=a.w
if(t===6||t===7)return A.dN(a.x)
return t===11||t===12},
f8(a){return a.as},
hv(a,b){var t,s=b.length
for(t=0;t<s;++t)if(!a[t].b(b[t]))return!1
return!0},
cG(a){return A.cn(v.typeUniverse,a,!1)},
hq(a,b){var t,s,r,q,p
if(a==null)return null
t=b.y
s=a.Q
if(s==null)s=a.Q=new Map()
r=b.as
q=s.get(r)
if(q!=null)return q
p=A.af(v.typeUniverse,a.x,t,0)
s.set(r,p)
return p},
af(a0,a1,a2,a3){var t,s,r,q,p,o,n,m,l,k,j,i,h,g,f,e,d,c,b,a=a1.w
switch(a){case 5:case 1:case 2:case 3:case 4:return a1
case 6:t=a1.x
s=A.af(a0,t,a2,a3)
if(s===t)return a1
return A.dW(a0,s,!0)
case 7:t=a1.x
s=A.af(a0,t,a2,a3)
if(s===t)return a1
return A.dV(a0,s,!0)
case 8:r=a1.y
q=A.aF(a0,r,a2,a3)
if(q===r)return a1
return A.bf(a0,a1.x,q)
case 9:p=a1.x
o=A.af(a0,p,a2,a3)
n=a1.y
m=A.aF(a0,n,a2,a3)
if(o===p&&m===n)return a1
return A.dd(a0,o,m)
case 10:l=a1.x
k=a1.y
j=A.aF(a0,k,a2,a3)
if(j===k)return a1
return A.dX(a0,l,j)
case 11:i=a1.x
h=A.af(a0,i,a2,a3)
g=a1.y
f=A.h9(a0,g,a2,a3)
if(h===i&&f===g)return a1
return A.dU(a0,h,f)
case 12:e=a1.y
a3+=e.length
d=A.aF(a0,e,a2,a3)
p=a1.x
o=A.af(a0,p,a2,a3)
if(d===e&&o===p)return a1
return A.de(a0,o,d,!0)
case 13:c=a1.x
if(c<a3)return a1
b=a2[c-a3]
if(b==null)return a1
return b
default:throw A.c(A.bo("Attempted to substitute unexpected RTI kind "+a))}},
aF(a,b,c,d){var t,s,r,q,p=b.length,o=A.co(p)
for(t=!1,s=0;s<p;++s){r=b[s]
q=A.af(a,r,c,d)
if(q!==r)t=!0
o[s]=q}return t?o:b},
ha(a,b,c,d){var t,s,r,q,p,o,n=b.length,m=A.co(n)
for(t=!1,s=0;s<n;s+=3){r=b[s]
q=b[s+1]
p=b[s+2]
o=A.af(a,p,c,d)
if(o!==p)t=!0
m.splice(s,3,r,q,o)}return t?m:b},
h9(a,b,c,d){var t,s=b.a,r=A.aF(a,s,c,d),q=b.b,p=A.aF(a,q,c,d),o=b.c,n=A.ha(a,o,c,d)
if(r===s&&p===q&&n===o)return b
t=new A.bR()
t.a=r
t.b=p
t.c=n
return t},
b(a,b){a[v.arrayRti]=b
return a},
cF(a){var t=a.$S
if(t!=null){if(typeof t=="number")return A.ho(t)
return a.$S()}return null},
hp(a,b){var t
if(A.dN(b))if(a instanceof A.F){t=A.cF(a)
if(t!=null)return t}return A.bk(a)},
bk(a){if(a instanceof A.k)return A.I(a)
if(Array.isArray(a))return A.u(a)
return A.di(J.as(a))},
u(a){var t=a[v.arrayRti],s=u.b
if(t==null)return s
if(t.constructor!==s.constructor)return s
return t},
I(a){var t=a.$ti
return t!=null?t:A.di(a)},
di(a){var t=a.constructor,s=t.$ccache
if(s!=null)return s
return A.fQ(a,t)},
fQ(a,b){var t=a instanceof A.F?Object.getPrototypeOf(Object.getPrototypeOf(a)).constructor:b,s=A.fu(v.typeUniverse,t.name)
b.$ccache=s
return s},
ho(a){var t,s=v.types,r=s[a]
if(typeof r=="string"){t=A.cn(v.typeUniverse,r,!1)
s[a]=t
return t}return r},
hn(a){return A.a4(A.I(a))},
dp(a){var t=A.cF(a)
return A.a4(t==null?A.bk(a):t)},
dk(a){var t
if(a instanceof A.U)return A.hk(a.$r,a.T())
t=a instanceof A.F?A.cF(a):null
if(t!=null)return t
if(u.bW.b(a))return J.eO(a).a
if(Array.isArray(a))return A.u(a)
return A.bk(a)},
a4(a){var t=a.r
return t==null?a.r=new A.cm(a):t},
hk(a,b){var t,s,r=b,q=r.length
if(q===0)return u.F
if(0>=q)return A.f(r,0)
t=A.bh(v.typeUniverse,A.dk(r[0]),"@<0>")
for(s=1;s<q;++s){if(!(s<r.length))return A.f(r,s)
t=A.dZ(v.typeUniverse,t,A.dk(r[s]))}return A.bh(v.typeUniverse,t,a)},
hH(a){return A.a4(A.cn(v.typeUniverse,a,!1))},
fP(a){var t=this
t.b=A.h8(t)
return t.b(a)},
h8(a){var t,s,r,q,p
if(a===u.K)return A.fY
if(A.at(a))return A.h1
t=a.w
if(t===6)return A.fM
if(t===1)return A.e8
if(t===7)return A.fT
s=A.h6(a)
if(s!=null)return s
if(t===8){r=a.x
if(a.y.every(A.at)){a.f="$i"+r
if(r==="o")return A.fW
if(a===u.m)return A.fV
return A.h0}}else if(t===10){q=A.hj(a.x,a.y)
p=q==null?A.e8:q
return p==null?A.dg(p):p}return A.fK},
h6(a){if(a.w===8){if(a===u.S)return A.e6
if(a===u.i||a===u.H)return A.fX
if(a===u.N)return A.h_
if(a===u.v)return A.dj}return null},
fO(a){var t=this,s=A.fJ
if(A.at(t))s=A.fD
else if(t===u.K)s=A.dg
else if(A.aG(t)){s=A.fL
if(t===u.a3)s=A.fA
else if(t===u.aD)s=A.dh
else if(t===u.cG)s=A.fy
else if(t===u.ae)s=A.e1
else if(t===u.I)s=A.fz
else if(t===u.aQ)s=A.fC}else if(t===u.S)s=A.ar
else if(t===u.N)s=A.O
else if(t===u.v)s=A.fx
else if(t===u.H)s=A.V
else if(t===u.i)s=A.df
else if(t===u.m)s=A.fB
t.a=s
return t.a(a)},
fK(a){var t=this
if(a==null)return A.aG(t)
return A.ef(v.typeUniverse,A.hp(a,t),t)},
fM(a){if(a==null)return!0
return this.x.b(a)},
h0(a){var t,s=this
if(a==null)return A.aG(s)
t=s.f
if(a instanceof A.k)return!!a[t]
return!!J.as(a)[t]},
fW(a){var t,s=this
if(a==null)return A.aG(s)
if(typeof a!="object")return!1
if(Array.isArray(a))return!0
t=s.f
if(a instanceof A.k)return!!a[t]
return!!J.as(a)[t]},
fV(a){var t=this
if(a==null)return!1
if(typeof a=="object"){if(a instanceof A.k)return!!a[t.f]
return!0}if(typeof a=="function")return!0
return!1},
e7(a){if(typeof a=="object"){if(a instanceof A.k)return u.m.b(a)
return!0}if(typeof a=="function")return!0
return!1},
fJ(a){var t=this
if(a==null){if(A.aG(t))return a}else if(t.b(a))return a
throw A.A(A.e2(a,t),new Error())},
fL(a){var t=this
if(a==null||t.b(a))return a
throw A.A(A.e2(a,t),new Error())},
e2(a,b){return new A.aE("TypeError: "+A.dQ(a,A.J(b,null)))},
eb(a,b,c,d){if(A.ef(v.typeUniverse,a,b))return a
throw A.A(A.fm("The type argument '"+A.J(a,null)+"' is not a subtype of the type variable bound '"+A.J(b,null)+"' of type variable '"+c+"' in '"+d+"'."),new Error())},
dQ(a,b){return A.bu(a)+": type '"+A.J(A.dk(a),null)+"' is not a subtype of type '"+b+"'"},
fm(a){return new A.aE("TypeError: "+a)},
S(a,b){return new A.aE("TypeError: "+A.dQ(a,b))},
fT(a){var t=this
return t.x.b(a)||A.db(v.typeUniverse,t).b(a)},
fY(a){return a!=null},
dg(a){if(a!=null)return a
throw A.A(A.S(a,"Object"),new Error())},
h1(a){return!0},
fD(a){return a},
e8(a){return!1},
dj(a){return!0===a||!1===a},
fx(a){if(!0===a)return!0
if(!1===a)return!1
throw A.A(A.S(a,"bool"),new Error())},
fy(a){if(!0===a)return!0
if(!1===a)return!1
if(a==null)return a
throw A.A(A.S(a,"bool?"),new Error())},
df(a){if(typeof a=="number")return a
throw A.A(A.S(a,"double"),new Error())},
fz(a){if(typeof a=="number")return a
if(a==null)return a
throw A.A(A.S(a,"double?"),new Error())},
e6(a){return typeof a=="number"&&Math.floor(a)===a},
ar(a){if(typeof a=="number"&&Math.floor(a)===a)return a
throw A.A(A.S(a,"int"),new Error())},
fA(a){if(typeof a=="number"&&Math.floor(a)===a)return a
if(a==null)return a
throw A.A(A.S(a,"int?"),new Error())},
fX(a){return typeof a=="number"},
V(a){if(typeof a=="number")return a
throw A.A(A.S(a,"num"),new Error())},
e1(a){if(typeof a=="number")return a
if(a==null)return a
throw A.A(A.S(a,"num?"),new Error())},
h_(a){return typeof a=="string"},
O(a){if(typeof a=="string")return a
throw A.A(A.S(a,"String"),new Error())},
dh(a){if(typeof a=="string")return a
if(a==null)return a
throw A.A(A.S(a,"String?"),new Error())},
fB(a){if(A.e7(a))return a
throw A.A(A.S(a,"JSObject"),new Error())},
fC(a){if(a==null)return a
if(A.e7(a))return a
throw A.A(A.S(a,"JSObject?"),new Error())},
ea(a,b){var t,s,r
for(t="",s="",r=0;r<a.length;++r,s=", ")t+=s+A.J(a[r],b)
return t},
h5(a,b){var t,s,r,q,p,o,n=a.x,m=a.y
if(""===n)return"("+A.ea(m,b)+")"
t=m.length
s=n.split(",")
r=s.length-t
for(q="(",p="",o=0;o<t;++o,p=", "){q+=p
if(r===0)q+="{"
q+=A.J(m[o],b)
if(r>=0)q+=" "+s[r];++r}return q+"})"},
e3(a2,a3,a4){var t,s,r,q,p,o,n,m,l,k,j,i,h,g,f,e,d,c,b,a,a0=", ",a1=null
if(a4!=null){t=a4.length
if(a3==null)a3=A.b([],u.s)
else a1=a3.length
s=a3.length
for(r=t;r>0;--r)B.a.i(a3,"T"+(s+r))
for(q=u.O,p="<",o="",r=0;r<t;++r,o=a0){n=a3.length
m=n-1-r
if(!(m>=0))return A.f(a3,m)
p=p+o+a3[m]
l=a4[r]
k=l.w
if(!(k===2||k===3||k===4||k===5||l===q))p+=" extends "+A.J(l,a3)}p+=">"}else p=""
q=a2.x
j=a2.y
i=j.a
h=i.length
g=j.b
f=g.length
e=j.c
d=e.length
c=A.J(q,a3)
for(b="",a="",r=0;r<h;++r,a=a0)b+=a+A.J(i[r],a3)
if(f>0){b+=a+"["
for(a="",r=0;r<f;++r,a=a0)b+=a+A.J(g[r],a3)
b+="]"}if(d>0){b+=a+"{"
for(a="",r=0;r<d;r+=3,a=a0){b+=a
if(e[r+1])b+="required "
b+=A.J(e[r+2],a3)+" "+e[r]}b+="}"}if(a1!=null){a3.toString
a3.length=a1}return p+"("+b+") => "+c},
J(a,b){var t,s,r,q,p,o,n,m=a.w
if(m===5)return"erased"
if(m===2)return"dynamic"
if(m===3)return"void"
if(m===1)return"Never"
if(m===4)return"any"
if(m===6){t=a.x
s=A.J(t,b)
r=t.w
return(r===11||r===12?"("+s+")":s)+"?"}if(m===7)return"FutureOr<"+A.J(a.x,b)+">"
if(m===8){q=A.hb(a.x)
p=a.y
return p.length>0?q+("<"+A.ea(p,b)+">"):q}if(m===10)return A.h5(a,b)
if(m===11)return A.e3(a,b,null)
if(m===12)return A.e3(a.x,b,a.y)
if(m===13){o=a.x
n=b.length
o=n-1-o
if(!(o>=0&&o<n))return A.f(b,o)
return b[o]}return"?"},
hb(a){var t=A.eo(a)
if(t!=null)return t
return"minified:"+a},
fv(a,b){var t=a.tR[b]
while(typeof t=="string")t=a.tR[t]
return t},
fu(a,b){var t,s,r,q,p,o=a.eT,n=o[b]
if(n==null)return A.cn(a,b,!1)
else if(typeof n=="number"){t=n
s=A.bg(a,5,"#")
r=A.co(t)
for(q=0;q<t;++q)r[q]=s
p=A.bf(a,b,r)
o[b]=p
return p}else return n},
ft(a,b){return A.e_(a.tR,b)},
fs(a,b){return A.e_(a.eT,b)},
cn(a,b,c){var t,s=a.eC,r=s.get(b)
if(r!=null)return r
t=A.dY(a,null,b,!1)
s.set(b,t)
return t},
bh(a,b,c){var t,s,r=b.z
if(r==null)r=b.z=new Map()
t=r.get(c)
if(t!=null)return t
s=A.dY(a,b,c,!0)
r.set(c,s)
return s},
dZ(a,b,c){var t,s,r,q=b.Q
if(q==null)q=b.Q=new Map()
t=c.as
s=q.get(t)
if(s!=null)return s
r=A.dd(a,b,c.w===9?c.y:[c])
q.set(t,r)
return r},
dY(a,b,c,d){return A.fj(A.fd(a,b,c,d))},
ae(a,b){b.a=A.fO
b.b=A.fP
return b},
bg(a,b,c){var t,s,r=a.eC.get(c)
if(r!=null)return r
t=new A.T(null,null)
t.w=b
t.as=c
s=A.ae(a,t)
a.eC.set(c,s)
return s},
dW(a,b,c){var t,s=b.as+"?",r=a.eC.get(s)
if(r!=null)return r
t=A.fq(a,b,s,c)
a.eC.set(s,t)
return t},
fq(a,b,c,d){var t,s,r
if(d){t=b.w
s=!0
if(!A.at(b))if(!(b===u.P||b===u.T))if(t!==6)s=t===7&&A.aG(b.x)
if(s)return b
else if(t===1)return u.P}r=new A.T(null,null)
r.w=6
r.x=b
r.as=c
return A.ae(a,r)},
dV(a,b,c){var t,s=b.as+"/",r=a.eC.get(s)
if(r!=null)return r
t=A.fo(a,b,s,c)
a.eC.set(s,t)
return t},
fo(a,b,c,d){var t,s
if(d){t=b.w
if(A.at(b)||b===u.K)return b
else if(t===1)return A.bf(a,"dC",[b])
else if(b===u.P||b===u.T)return u.bc}s=new A.T(null,null)
s.w=7
s.x=b
s.as=c
return A.ae(a,s)},
fr(a,b){var t,s,r=""+b+"^",q=a.eC.get(r)
if(q!=null)return q
t=new A.T(null,null)
t.w=13
t.x=b
t.as=r
s=A.ae(a,t)
a.eC.set(r,s)
return s},
be(a){var t,s,r,q=a.length
for(t="",s="",r=0;r<q;++r,s=",")t+=s+a[r].as
return t},
fn(a){var t,s,r,q,p,o=a.length
for(t="",s="",r=0;r<o;r+=3,s=","){q=a[r]
p=a[r+1]?"!":":"
t+=s+q+p+a[r+2].as}return t},
bf(a,b,c){var t,s,r,q=b
if(c.length>0)q+="<"+A.be(c)+">"
t=a.eC.get(q)
if(t!=null)return t
s=new A.T(null,null)
s.w=8
s.x=b
s.y=c
if(c.length>0)s.c=c[0]
s.as=q
r=A.ae(a,s)
a.eC.set(q,r)
return r},
dd(a,b,c){var t,s,r,q,p,o
if(b.w===9){t=b.x
s=b.y.concat(c)}else{s=c
t=b}r=t.as+(";<"+A.be(s)+">")
q=a.eC.get(r)
if(q!=null)return q
p=new A.T(null,null)
p.w=9
p.x=t
p.y=s
p.as=r
o=A.ae(a,p)
a.eC.set(r,o)
return o},
dX(a,b,c){var t,s,r="+"+(b+"("+A.be(c)+")"),q=a.eC.get(r)
if(q!=null)return q
t=new A.T(null,null)
t.w=10
t.x=b
t.y=c
t.as=r
s=A.ae(a,t)
a.eC.set(r,s)
return s},
dU(a,b,c){var t,s,r,q,p,o=b.as,n=c.a,m=n.length,l=c.b,k=l.length,j=c.c,i=j.length,h="("+A.be(n)
if(k>0){t=m>0?",":""
h+=t+"["+A.be(l)+"]"}if(i>0){t=m>0?",":""
h+=t+"{"+A.fn(j)+"}"}s=o+(h+")")
r=a.eC.get(s)
if(r!=null)return r
q=new A.T(null,null)
q.w=11
q.x=b
q.y=c
q.as=s
p=A.ae(a,q)
a.eC.set(s,p)
return p},
de(a,b,c,d){var t,s=b.as+("<"+A.be(c)+">"),r=a.eC.get(s)
if(r!=null)return r
t=A.fp(a,b,c,s,d)
a.eC.set(s,t)
return t},
fp(a,b,c,d,e){var t,s,r,q,p,o,n,m
if(e){t=c.length
s=A.co(t)
for(r=0,q=0;q<t;++q){p=c[q]
if(p.w===1){s[q]=p;++r}}if(r>0){o=A.af(a,b,s,0)
n=A.aF(a,c,s,0)
return A.de(a,o,n,c!==n)}}m=new A.T(null,null)
m.w=12
m.x=b
m.y=c
m.as=d
return A.ae(a,m)},
fd(a,b,c,d){return{u:a,e:b,r:c,s:[],p:0,n:d}},
fj(a){var t,s,r,q,p,o,n,m=a.r,l=a.s
for(t=m.length,s=0;s<t;){r=m.charCodeAt(s)
if(r>=48&&r<=57)s=A.ff(s+1,r,m,l)
else if((((r|32)>>>0)-97&65535)<26||r===95||r===36||r===124)s=A.dS(a,s,m,l,!1)
else if(r===46)s=A.dS(a,s,m,l,!0)
else{++s
switch(r){case 44:break
case 58:l.push(!1)
break
case 33:l.push(!0)
break
case 59:l.push(A.aq(a.u,a.e,l.pop()))
break
case 94:l.push(A.fr(a.u,l.pop()))
break
case 35:l.push(A.bg(a.u,5,"#"))
break
case 64:l.push(A.bg(a.u,2,"@"))
break
case 126:l.push(A.bg(a.u,3,"~"))
break
case 60:l.push(a.p)
a.p=l.length
break
case 62:A.fh(a,l)
break
case 38:A.fg(a,l)
break
case 63:q=a.u
l.push(A.dW(q,A.aq(q,a.e,l.pop()),a.n))
break
case 47:q=a.u
l.push(A.dV(q,A.aq(q,a.e,l.pop()),a.n))
break
case 40:l.push(-3)
l.push(a.p)
a.p=l.length
break
case 41:A.fe(a,l)
break
case 91:l.push(a.p)
a.p=l.length
break
case 93:p=l.splice(a.p)
A.dT(a.u,a.e,p)
a.p=l.pop()
l.push(p)
l.push(-1)
break
case 123:l.push(a.p)
a.p=l.length
break
case 125:p=l.splice(a.p)
A.fk(a.u,a.e,p)
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
return A.aq(a.u,a.e,n)},
ff(a,b,c,d){var t,s,r=b-48
for(t=c.length;a<t;++a){s=c.charCodeAt(a)
if(!(s>=48&&s<=57))break
r=r*10+(s-48)}d.push(r)
return a},
dS(a,b,c,d,e){var t,s,r,q,p,o,n=b+1
for(t=c.length;n<t;++n){s=c.charCodeAt(n)
if(s===46){if(e)break
e=!0}else{if(!((((s|32)>>>0)-97&65535)<26||s===95||s===36||s===124))r=s>=48&&s<=57
else r=!0
if(!r)break}}q=c.substring(b,n)
if(e){t=a.u
p=a.e
if(p.w===9)p=p.x
o=A.fv(t,p.x)[q]
if(o==null)A.d4('No "'+q+'" in "'+A.f8(p)+'"')
d.push(A.bh(t,p,o))}else d.push(q)
return n},
fh(a,b){var t,s=a.u,r=A.dR(a,b),q=b.pop()
if(typeof q=="string")b.push(A.bf(s,q,r))
else{t=A.aq(s,a.e,q)
switch(t.w){case 11:b.push(A.de(s,t,r,a.n))
break
default:b.push(A.dd(s,t,r))
break}}},
fe(a,b){var t,s,r,q=a.u,p=b.pop(),o=null,n=null
if(typeof p=="number")switch(p){case-1:o=b.pop()
break
case-2:n=b.pop()
break
default:b.push(p)
break}else b.push(p)
t=A.dR(a,b)
p=b.pop()
switch(p){case-3:p=b.pop()
if(o==null)o=q.sEA
if(n==null)n=q.sEA
s=A.aq(q,a.e,p)
r=new A.bR()
r.a=t
r.b=o
r.c=n
b.push(A.dU(q,s,r))
return
case-4:b.push(A.dX(q,b.pop(),t))
return
default:throw A.c(A.bo("Unexpected state under `()`: "+A.n(p)))}},
fg(a,b){var t=b.pop()
if(0===t){b.push(A.bg(a.u,1,"0&"))
return}if(1===t){b.push(A.bg(a.u,4,"1&"))
return}throw A.c(A.bo("Unexpected extended operation "+A.n(t)))},
dR(a,b){var t=b.splice(a.p)
A.dT(a.u,a.e,t)
a.p=b.pop()
return t},
aq(a,b,c){if(typeof c=="string")return A.bf(a,c,a.sEA)
else if(typeof c=="number"){b.toString
return A.fi(a,b,c)}else return c},
dT(a,b,c){var t,s=c.length
for(t=0;t<s;++t)c[t]=A.aq(a,b,c[t])},
fk(a,b,c){var t,s=c.length
for(t=2;t<s;t+=3)c[t]=A.aq(a,b,c[t])},
fi(a,b,c){var t,s,r=b.w
if(r===9){if(c===0)return b.x
t=b.y
s=t.length
if(c<=s)return t[c-1]
c-=s
b=b.x
r=b.w}else if(c===0)return b
if(r!==8)throw A.c(A.bo("Indexed base must be an interface type"))
t=b.y
if(c<=t.length)return t[c-1]
throw A.c(A.bo("Bad index "+c+" for "+b.j(0)))},
ef(a,b,c){var t,s=b.d
if(s==null)s=b.d=new Map()
t=s.get(c)
if(t==null){t=A.w(a,b,null,c,null)
s.set(c,t)}return t},
w(a,b,c,d,e){var t,s,r,q,p,o,n,m,l,k,j
if(b===d)return!0
if(A.at(d))return!0
t=b.w
if(t===4)return!0
if(A.at(b))return!1
if(b.w===1)return!0
s=t===13
if(s)if(A.w(a,c[b.x],c,d,e))return!0
r=d.w
q=u.P
if(b===q||b===u.T){if(r===7)return A.w(a,b,c,d.x,e)
return d===q||d===u.T||r===6}if(d===u.K){if(t===7)return A.w(a,b.x,c,d,e)
return t!==6}if(t===7){if(!A.w(a,b.x,c,d,e))return!1
return A.w(a,A.db(a,b),c,d,e)}if(t===6)return A.w(a,q,c,d,e)&&A.w(a,b.x,c,d,e)
if(r===7){if(A.w(a,b,c,d.x,e))return!0
return A.w(a,b,c,A.db(a,d),e)}if(r===6)return A.w(a,b,c,q,e)||A.w(a,b,c,d.x,e)
if(s)return!1
q=t!==11
if((!q||t===12)&&d===u.Z)return!0
p=t===10
if(p&&d===u.cY)return!0
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
if(!A.w(a,k,c,j,e)||!A.w(a,j,e,k,c))return!1}return A.e5(a,b.x,c,d.x,e)}if(r===11){if(b===u.g)return!0
if(q)return!1
return A.e5(a,b,c,d,e)}if(t===8){if(r!==8)return!1
return A.fU(a,b,c,d,e)}if(p&&r===10)return A.fZ(a,b,c,d,e)
return!1},
e5(a2,a3,a4,a5,a6){var t,s,r,q,p,o,n,m,l,k,j,i,h,g,f,e,d,c,b,a,a0,a1
if(!A.w(a2,a3.x,a4,a5.x,a6))return!1
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
if(!A.w(a2,q[i],a6,h,a4))return!1}for(i=0;i<n;++i){h=m[i]
if(!A.w(a2,q[p+i],a6,h,a4))return!1}for(i=0;i<j;++i){h=m[n+i]
if(!A.w(a2,l[i],a6,h,a4))return!1}g=t.c
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
if(!A.w(a2,f[b+2],a6,h,a4))return!1
break}}while(c<e){if(g[c+1])return!1
c+=3}return!0},
fU(a,b,c,d,e){var t,s,r,q,p,o=b.x,n=d.x
while(o!==n){t=a.tR[o]
if(t==null)return!1
if(typeof t=="string"){o=t
continue}s=t[n]
if(s==null)return!1
r=s.length
q=r>0?new Array(r):v.typeUniverse.sEA
for(p=0;p<r;++p)q[p]=A.bh(a,b,s[p])
return A.e0(a,q,null,c,d.y,e)}return A.e0(a,b.y,null,c,d.y,e)},
e0(a,b,c,d,e,f){var t,s=b.length
for(t=0;t<s;++t)if(!A.w(a,b[t],d,e[t],f))return!1
return!0},
fZ(a,b,c,d,e){var t,s=b.y,r=d.y,q=s.length
if(q!==r.length)return!1
if(b.x!==d.x)return!1
for(t=0;t<q;++t)if(!A.w(a,s[t],c,r[t],e))return!1
return!0},
aG(a){var t=a.w,s=!0
if(!(a===u.P||a===u.T))if(!A.at(a))if(t!==6)s=t===7&&A.aG(a.x)
return s},
at(a){var t=a.w
return t===2||t===3||t===4||t===5||a===u.O},
e_(a,b){var t,s,r=Object.keys(b),q=r.length
for(t=0;t<q;++t){s=r[t]
a[s]=b[s]}},
co(a){return a>0?new Array(a):v.typeUniverse.sEA},
T:function T(a,b){var _=this
_.a=a
_.b=b
_.r=_.f=_.d=_.c=null
_.w=0
_.as=_.Q=_.z=_.y=_.x=null},
bR:function bR(){this.c=this.b=this.a=null},
cm:function cm(a){this.a=a},
bQ:function bQ(){},
aE:function aE(a){this.a=a},
c5(a,b,c){return b.h("@<0>").E(c).h("dH<1,2>").a(A.hl(a,new A.ak(b.h("@<0>").E(c).h("ak<1,2>"))))},
f4(a,b){return new A.ak(a.h("@<0>").E(b).h("ak<1,2>"))},
c6(a){return new A.b9(a.h("b9<0>"))},
dc(){var t=Object.create(null)
t["<non-identifier-key>"]=t
delete t["<non-identifier-key>"]
return t},
dJ(a){var t,s
if(A.dq(a))return"{...}"
t=new A.ab("")
try{s={}
B.a.i($.P,a)
t.a+="{"
s.a=!0
a.P(0,new A.c7(s,t))
t.a+="}"}finally{if(0>=$.P.length)return A.f($.P,-1)
$.P.pop()}s=t.a
return s.charCodeAt(0)==0?s:s},
b9:function b9(a){var _=this
_.a=0
_.f=_.e=_.d=_.c=_.b=null
_.r=0
_.$ti=a},
bU:function bU(a){this.a=a
this.b=null},
ap:function ap(a,b,c){var _=this
_.a=a
_.b=b
_.d=_.c=null
_.$ti=c},
C:function C(){},
M:function M(){},
c7:function c7(a,b){this.a=a
this.b=b},
aa:function aa(){},
bd:function bd(){},
h4(a,b){var t,s,r,q=null
try{q=JSON.parse(a)}catch(s){t=A.dr(s)
r=A.dB(String(t),null)
throw A.c(r)}r=A.cs(q)
return r},
cs(a){var t
if(a==null)return null
if(typeof a!="object")return a
if(!Array.isArray(a))return new A.bS(a,Object.create(null))
for(t=0;t<a.length;++t)a[t]=A.cs(a[t])
return a},
dG(a,b,c){return new A.aR(a,b)},
fG(a){return a.b7()},
fb(a,b){return new A.ci(a,[],A.hi())},
fc(a,b,c){var t,s=new A.ab(""),r=A.fb(s,b)
r.a1(a)
t=s.a
return t.charCodeAt(0)==0?t:t},
bS:function bS(a,b){this.a=a
this.b=b
this.c=null},
bT:function bT(a){this.a=a},
br:function br(){},
bt:function bt(){},
aR:function aR(a,b){this.a=a
this.b=b},
bC:function bC(a,b){this.a=a
this.b=b},
c1:function c1(){},
c3:function c3(a){this.b=a},
c2:function c2(a){this.a=a},
cj:function cj(){},
ck:function ck(a,b){this.a=a
this.b=b},
ci:function ci(a,b,c){this.c=a
this.a=b
this.b=c},
dI(a,b,c,d){var t,s=c?J.f0(a,d):J.f_(a,d)
if(a!==0&&b!=null)for(t=0;t<s.length;++t)s[t]=b
return s},
f5(a,b,c){var t,s,r=A.b([],c.h("i<0>"))
for(t=a.length,s=0;s<a.length;a.length===t||(0,A.j)(a),++s)B.a.i(r,c.a(a[s]))
r.$flags=1
return r},
an(a,b){var t,s
if(Array.isArray(a))return A.b(a.slice(0),b.h("i<0>"))
t=A.b([],b.h("i<0>"))
for(s=J.bm(a);s.l();)B.a.i(t,s.gm())
return t},
z(a,b){return new A.aP(a,A.dF(a,!1,b,!1,!1,""))},
dO(a,b,c){var t=J.bm(b)
if(!t.l())return a
if(c.length===0){do a+=A.n(t.gm())
while(t.l())}else{a+=A.n(t.gm())
while(t.l())a=a+c+A.n(t.gm())}return a},
bu(a){if(typeof a=="number"||A.dj(a)||a==null)return J.aI(a)
if(typeof a=="string")return JSON.stringify(a)
return A.dL(a)},
bo(a){return new A.bn(a)},
d5(a){return new A.a5(!1,null,null,a)},
dM(a,b){return new A.b_(null,null,!0,a,b,"Value not in range")},
R(a,b,c,d,e){return new A.b_(b,c,!0,a,d,"Invalid value")},
f7(a,b,c){if(0>a||a>c)throw A.c(A.R(a,0,c,"start",null))
if(b!=null){if(a>b||b>c)throw A.c(A.R(b,a,c,"end",null))
return b}return c},
bH(a,b){if(a<0)throw A.c(A.R(a,0,null,b,null))
return a},
d7(a,b,c,d){return new A.bv(b,!0,a,d,"Index out of range")},
cg(a){return new A.b4(a)},
G(a){return new A.bs(a)},
dB(a,b){return new A.aM(a,b)},
eZ(a,b,c){var t,s
if(A.dq(a)){if(b==="("&&c===")")return"(...)"
return b+"..."+c}t=A.b([],u.s)
B.a.i($.P,a)
try{A.h2(a,t)}finally{if(0>=$.P.length)return A.f($.P,-1)
$.P.pop()}s=A.dO(b,u.a.a(t),", ")+c
return s.charCodeAt(0)==0?s:s},
d8(a,b,c){var t,s
if(A.dq(a))return b+"..."+c
t=new A.ab(b)
B.a.i($.P,a)
try{s=t
s.a=A.dO(s.a,a,", ")}finally{if(0>=$.P.length)return A.f($.P,-1)
$.P.pop()}t.a+=c
s=t.a
return s.charCodeAt(0)==0?s:s},
h2(a,b){var t,s,r,q,p,o,n,m=a.gn(a),l=0,k=0
for(;;){if(!(l<80||k<3))break
if(!m.l())return
t=A.n(m.gm())
B.a.i(b,t)
l+=t.length+2;++k}if(!m.l()){if(k<=5)return
if(0>=b.length)return A.f(b,-1)
s=b.pop()
if(0>=b.length)return A.f(b,-1)
r=b.pop()}else{q=m.gm();++k
if(!m.l()){if(k<=4){B.a.i(b,A.n(q))
return}s=A.n(q)
if(0>=b.length)return A.f(b,-1)
r=b.pop()
l+=s.length+2}else{p=m.gm();++k
for(;m.l();q=p,p=o){o=m.gm();++k
if(k>100){for(;;){if(!(l>75&&k>3))break
if(0>=b.length)return A.f(b,-1)
l-=b.pop().length+2;--k}B.a.i(b,"...")
return}}r=A.n(q)
s=A.n(p)
l+=s.length+r.length+4}}if(k>b.length+2){l+=5
n="..."}else n=null
for(;;){if(!(l>80&&b.length>3))break
if(0>=b.length)return A.f(b,-1)
l-=b.pop().length+2
if(n==null){l+=5
n="..."}}if(n!=null)B.a.i(b,n)
B.a.i(b,r)
B.a.i(b,s)},
c9(a,b,c,d){var t
if(B.e===c){t=J.K(a)
b=J.K(b)
return A.cd(A.a0(A.a0($.bY(),t),b))}if(B.e===d){t=J.K(a)
b=J.K(b)
c=J.K(c)
return A.cd(A.a0(A.a0(A.a0($.bY(),t),b),c))}t=J.K(a)
b=J.K(b)
c=J.K(c)
d=J.K(d)
d=A.cd(A.a0(A.a0(A.a0(A.a0($.bY(),t),b),c),d))
return d},
f6(a){var t,s,r=$.bY()
for(t=a.length,s=0;s<a.length;a.length===t||(0,A.j)(a),++s)r=A.a0(r,J.K(a[s]))
return A.cd(r)},
t:function t(){},
bn:function bn(a){this.a=a},
b3:function b3(){},
a5:function a5(a,b,c,d){var _=this
_.a=a
_.b=b
_.c=c
_.d=d},
b_:function b_(a,b,c,d,e,f){var _=this
_.e=a
_.f=b
_.a=c
_.b=d
_.c=e
_.d=f},
bv:function bv(a,b,c,d,e){var _=this
_.f=a
_.a=b
_.b=c
_.c=d
_.d=e},
b4:function b4(a){this.a=a},
bJ:function bJ(a){this.a=a},
bs:function bs(a){this.a=a},
b2:function b2(){},
ch:function ch(a){this.a=a},
aM:function aM(a,b){this.a=a
this.b=b},
e:function e(){},
a8:function a8(a,b,c){this.a=a
this.b=b
this.$ti=c},
aY:function aY(){},
k:function k(){},
ab:function ab(a){this.a=a},
d6(a,b,c){return new A.bZ(c,a)},
hz(a,b,c,d){var t,s,r,q,p,o,n,m,l,k,j,i=null,h=u.s,g=A.b([],h)
for(t=c.length,s=0;s<c.length;c.length===t||(0,A.j)(c),++s){r=c[s]
q=!1
if(r.length<80){p=$.eD()
if(p.b.test(r)){q=A.z("\\d|prologue|epilogue|[\u4e00\u4e8c\u4e09\u56db\u4e94\u516d\u4e03\u516b\u4e5d\u5341]",!1)
q=q.b.test(r)}}g.push(q?"# "+r:r)}t=u.Q
q=u.z
o=0
r=1
for(;;){if(!(r<=3&&o===0))break
if(new A.D(g,t.a(new A.d2(r)),q).gk(0)>=2)o=r;++r}n=A.b([],u.p)
if(o===0)B.a.i(n,new A.Q(a,g,i))
else for(t=g.length,m=i,s=0;s<g.length;g.length===t||(0,A.j)(g),++s){l=g[s]
k=A.ee(l)
if(k>0&&k<=o){q=$.dt()
m=new A.Q(A.en(l,q,"",0),A.b([],h),i)
B.a.i(n,m)}else{if(m==null){j=new A.Q(a,A.b([],h),i)
B.a.i(n,j)
q=j
m=q}else q=m
B.a.i(q.b,l)}}B.a.aX(n,new A.d3(n,a))
return A.d6(n,b,a)},
Q:function Q(a,b,c){this.a=a
this.b=b
this.c=c},
bZ:function bZ(a,b){this.a=a
this.w=b},
d2:function d2(a){this.a=a},
d3:function d3(a,b){this.a=a
this.b=b},
el(a,a0,a1){var t,s,r,q,p,o,n,m,l,k,j,i,h,g,f={},e=B.a.aM(a,new A.cT()),d=u.s,c=A.b([],d),b=A.b([],u.X)
for(t=0;t<a.length;++t){s=a[t]
s=A.aH(s,"\r\n","\n")
s=A.aH(s,"\r","\n").split("\n")
r=s.length
q=a0+t
p=0
for(;p<r;++p){o=s[p]
if(B.b.J(o,"\u2029"))n=B.b.v(A.aH(o,"\u2029","")).length===0
else n=!1
if(n){B.a.i(c,"\u2029")
B.a.i(b,q)
continue}n=A.z("[\\s\xa0]+",!0)
o=B.b.v(A.aH(o,n," "))
n=A.z("^(page\\s*)?\\d{1,4}(\\s*(of|/)\\s*\\d+)?$",!1)
B.a.i(c,n.b.test(o)?"":o)
B.a.i(b,q)}B.a.i(c,"")
B.a.i(b,q)}s=u.bw
m=A.an(new A.aW(new A.D(c,u.Q.a(new A.cU()),u.z),u.bv.a(new A.cV()),s),s.h("e.E"))
B.a.ac(m)
s=m.length
if(s===0)l=80
else{s=B.d.M(B.c.aS(s*0.8),0,m.length-1)
if(!(s>=0&&s<m.length))return A.f(m,s)
l=m[s]}k=A.b([],d)
j=new A.ab("")
f.a=a0
i=new A.cW(f,j,k,a1)
for(d=l*0.72,h=0;h<c.length;++h){o=c[h]
if(o==="\u2029"){i.$0()
continue}s=o.length
if(s===0){s=j.a
g=B.b.b_(s.charCodeAt(0)==0?s:s)
if(g.length!==0){s=$.du()
s=s.b.test(g)}else s=!1
if(s)i.$0()
continue}if(s<70){r=$.eG()
r=r.b.test(o)}else r=!1
if(r){i.$0()
B.a.i(k,o)
if(!(h<b.length))return A.f(b,h)
B.a.i(a1,b[h])
continue}r=j.a
g=r.charCodeAt(0)==0?r:r
if(B.b.v(g).length===0){if(!(h<b.length))return A.f(b,h)
f.a=b[h]}r=!1
if(B.b.X(g,"-"))if(!B.b.X(g," -")){r=A.z("^[a-z]",!0)
r=r.b.test(o)}if(r){j.a=""
r=B.b.H(g,0,g.length-1)
j.a=r
j.a=r+o}else{if(g.length!==0)j.a+=" "
j.a+=o}if(e)continue
if(s<d){s=$.du()
s=s.b.test(o)}else s=!1
if(s)i.$0()}i.$0()
return k},
hd(a,b){var t,s,r,q,p,o,n,m,l,k,j,i=u.N,h=A.f4(i,u.S)
for(t=b.length,s=0;s<b.length;b.length===t||(0,A.j)(b),++s){r=b[s]
if(r==null)continue
q=A.c6(i)
for(p=r.a,o=p.length,n=0;n<p.length;p.length===o||(0,A.j)(p),++n)q.i(0,A.ej(p[n],r))
p=q.$ti
o=new A.ap(q,q.r,p.h("ap<1>"))
o.c=q.e
p=p.c
while(o.l()){q=o.d
if(q==null)q=p.a(q)
if(q.length!==0){m=h.D(0,q)
h.A(0,q,(m==null?0:m)+1)}}}t=A.u(b)
l=Math.max(3,B.c.aN(new A.D(b,t.h("p(1)").a(new A.cB()),t.h("D<1>")).gk(0)*0.25))
i=A.c6(i)
for(t=new A.aS(h,h.$ti.h("aS<1,2>")).gn(0);t.l();){k=t.d
if(k.b>=l)i.i(0,k.a)}for(j=0;j<b.length;++j){r=b[j]
if(r!=null&&r.a.length!==0)B.a.A(a,j,A.hr(r,i))}},
hf(a8,a9,b0){var t,s,r,q,p,o,n,m,l,k,j,i,h,g,f,e,d,c,b,a,a0,a1,a2,a3,a4,a5,a6,a7=A.an(a9,u.x)
if(B.a.aT(a8,0,new A.cC(),u.S)<40*B.d.M(a8.length,1,5))throw A.c(B.l)
t=B.b.aY(b0,A.z("\\.pdf$",!1),"")
B.a.F(a7,new A.cD())
s=new A.cE(a8)
if(a7.length>=2){r=A.b([],u.p)
if(B.a.gO(a7).b>1){q=s.$3(t,0,B.d.M(B.a.gO(a7).b-1,0,a8.length))
if(q.b.length!==0)B.a.i(r,q)}for(p=0;p<a7.length;p=n){o=B.d.M(a7[p].b-1,0,a8.length-1)
n=p+1
m=a7.length
l=a8.length
if(n<m)l=B.d.M(a7[n].b-1,o,l)
if(!(p<a7.length))return A.f(a7,p)
m=a7[p]
k=l===o?o+1:l
j=s.$3(m.a,o,k)
if(j.b.length!==0)B.a.i(r,j)}if(r.length!==0)return A.d6(r,"PDF",t)}a7=u.X
i=A.b([],a7)
h=A.el(a8,0,i)
g=A.hz(t,"PDF",h,!0)
m=g.w
k=m.length
if(k>1){for(f=0,e=0;e<m.length;m.length===k||(0,A.j)(m),++e){j=m[e]
d=A.b([],a7)
for(c=j.b,b=c.length,a=0;a<c.length;c.length===b||(0,A.j)(c),++a){a0=c[a]
a1=h.length
a2=f
for(;;){a3=a2<a1
if(a3){if(!(a2>=0))return A.f(h,a2)
a4=h[a2]!==a0}else a4=!1
if(!a4)break;++a2}if(a3)f=a2+1
if(a3){if(!(a2>=0&&a2<i.length))return A.f(i,a2)
a1=i[a2]}else a1=d.length===0?0:B.a.ga_(d)
B.a.i(d,a1)}j.saV(d)}return g}r=A.b([],u.p)
for(a5=0;a7=a8.length,a5<a7;a5=a6){a6=a5+10
l=B.d.M(a6,0,a7)
j=s.$3(a8.length<=10?t:"Pages "+(a5+1)+"\u2013"+l,a5,l)
if(j.b.length!==0)B.a.i(r,j)}return A.d6(r,"PDF",t)},
cT:function cT(){},
cU:function cU(){},
cV:function cV(){},
cW:function cW(a,b,c,d){var _=this
_.a=a
_.b=b
_.c=c
_.d=d},
cB:function cB(){},
cC:function cC(){},
cD:function cD(){},
cE:function cE(a){this.a=a},
W(a){var t,s,r
if(a.length===0)return 0
t=A.an(a,u.i)
B.a.ac(t)
s=t.length
r=s/2|0
if(!(r<s))return A.f(t,r)
return t[r]},
h7(a,b){var t,s,r=new A.cA(a,b),q=r.$1($.eB())
if(J.L(q)!==0)return A.W(q)
t=r.$1($.eE())
if(J.L(t)!==0)return A.W(t)
s=r.$1($.eH())
if(J.L(s)!==0)return A.W(s)/0.68
return A.W(b)},
hx(a4,a5,a6){var t,s,r,q,p,o,n,m,l,k,j,i,h,g,f,e,d,c,b,a,a0,a1={},a2=A.b([],u.E),a3=new A.ab("")
a1.a=null
t=A.b([],u.t)
s=A.b([],u.s)
r=new A.cY(a1,a3,a2,s,t)
q=a4.length
p=Math.min(q,a5.length)
for(o=0,n=0;n<p;++n){if(!(n<q))return A.f(a4,n)
m=a4[n]
if(m==="\n"||m==="\r"){r.$0()
continue}if(!(n<a5.length))return A.f(a5,n)
l=a5[n].a
k=l[0]
j=l[1]
i=l[2]
h=l[3]
if(B.b.v(m).length===0||i<=k||j<=h){if(a1.a!=null)a3.a+=" "
continue}l=a6-j
g=a6-h
f=new A.l(k,l,i,g)
e=a1.a
if(e!=null){d=Math.max(g-l,A.W(t))
c=(l+g)/2
b=d*0.2
a=c>e.b-b&&c<e.d+b
a0=k-o
if(!a||a0>d*1.6||a0<-d*2)r.$0()}b=a1.a
if(b==null)a1.a=f
else a1.a=b.R(f)
a3.a+=m
B.a.i(t,g-l)
B.a.i(s,m)
o=i}r.$0()
return A.fI(a2)},
fI(a){var t,s,r,q,p,o,n,m,l,k,j,i,h,g,f,e,d,c=u.E,b=A.b([],c)
for(t=a.length,s=0;s<a.length;a.length===t||(0,A.j)(a),++s){r=a[s]
if(r.a.length===1)b.push(r)}B.a.F(b,new A.ct())
t=b.length
if(t<4)return a
q=u.n
p=A.c6(q)
o=A.c6(q)
for(s=0;s<b.length;b.length===t||(0,A.j)(b),++s){n=b[s]
if(o.J(0,n))continue
m=A.b([n],c)
for(q=b.length,l=n,k=0;k<b.length;b.length===q||(0,A.j)(b),++k){j=b[k]
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
l=j}}if(m.length>=4){p.U(0,m)
o.U(0,m)}}if(p.a===0)return a
c=A.b([],c)
for(b=a.length,s=0;s<a.length;a.length===b||(0,A.j)(a),++s){r=a[s]
if(!p.J(0,r))c.push(r)}return c},
e4(a,b){var t,s,r,q,p,o,n,m=u.G,l=A.b([],m)
for(t=a.length,s=0;s<a.length;a.length===t||(0,A.j)(a),++s){r=a[s]
l.push(b?new A.ad(r.a,r.c):new A.ad(r.b,r.d))}B.a.F(l,new A.cu())
q=A.b([],m)
p=B.a.gO(l).b
for(m=A.fa(l,1,null,u.o),l=m.$ti,m=new A.x(m,m.gk(0),l.h("x<y.E>")),l=l.h("y.E");m.l();){t=m.d
if(t==null)t=l.a(t)
o=t.a
n=t.b
if(o>p)B.a.i(q,new A.ad(p,o))
p=Math.max(p,n)}return q},
eg(a5,a6,a7){var t,s,r,q,p,o,n,m,l,k,j,i,h,g,f,e,d,c,b,a,a0,a1,a2,a3,a4
if(a5.length===0)return new A.a9(B.r,a7)
t=u.t
s=A.b([],t)
for(r=a5.length,q=0;q<a5.length;a5.length===r||(0,A.j)(a5),++q)s.push(a5[q].c)
p=Math.max(A.W(s),1)
o=A.b([],u.c)
new A.cL(o,p).$2(a5,0)
A.h3(o,p)
n=A.b([],u.V)
m=A.b([],u.u)
for(s=o.length,r=u.A,l=u.aR,k=u.E,q=0;q<o.length;o.length===s||(0,A.j)(o),++q){j=o[q]
B.a.F(j,new A.cI())
i=A.b([],k)
for(h=B.a.gn(j);h.l();){g=h.gm()
f=i.length===0?null:B.a.ga_(i)
if(f!=null){e=f.b
d=g.b
if(A.bj(e,d)&&d.a>=e.c-1){c=Math.max(f.c,g.c)
b=d.a-e.c>c*0.3?" ":""
B.a.A(i,i.length-1,new A.q(f.a+b+g.a,e.R(d),c))
continue}}B.a.i(i,new A.q(g.a,g.b,g.c))}a=new A.N(i,r.a(new A.cJ()),l).K(0,new A.cK())
a0=m.length
B.a.i(m,a)
h=A.b([],t)
for(a1=1;a1<i.length;++a1){g=i[a1].b.b
e=i[a1-1].b.b
if(g>e)h.push(g-e)}a2=h.length>=2?A.W(h):0
for(h=i.length,a3=0;a3<i.length;i.length===h||(0,A.j)(i),++a3){a4=i[a3]
B.a.i(n,new A.al(a4.a,a4.b,a4.c,a0,a,a2))}}return new A.a9(n,a7)},
h3(a4,a5){var t,s,r,q,p,o,n,m,l,k,j,i,h,g,f,e,d,c,b,a,a0,a1,a2=new A.cw(),a3=new A.cz()
for(t=a5*0.3,s=a5*1.5,r=a5*2.5,q=u.n,p=0;o=p+1,n=a4.length,o<n;){if(!(p<n))return A.f(a4,p)
m=a2.$1(a4[p])
if(!(o<a4.length))return A.f(a4,o)
l=a2.$1(a4[o])
if(!(p<a4.length))return A.f(a4,p)
k=a3.$1(a4[p])
if(!(o<a4.length))return A.f(a4,o)
j=a3.$1(a4[o])
i=m.R(l)
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
if(a&&a0&&a1){if(!(p<a4.length))return A.f(a4,p)
n=A.an(a4[p],q)
if(!(o<a4.length))return A.f(a4,o)
B.a.U(n,a4[o])
B.a.A(a4,p,n)
B.a.aW(a4,o)}else p=o}},
fw(a,b){var t,s,r,q,p,o,n,m,l,k,j,i=A.an(a,u.n)
B.a.F(i,new A.cp())
t=A.b([],u.t)
for(s=i.length,r=null,q=0;q<i.length;i.length===s||(0,A.j)(i),++q){p=i[q]
o=r!=null&&A.bj(r,p.b)
n=p.b
m=n.a
if(o)B.a.A(t,t.length-1,Math.min(B.a.ga_(t),m))
else{B.a.i(t,m)
r=n}}l=B.a.K(t,B.h)
i=u.ax
s=u.bL
k=new A.D(t,i.a(new A.cq(l,b)),s).gk(0)
j=new A.D(t,i.a(new A.cr(l,b)),s).gk(0)
if(k>=2){i=t.length
i=k+j>=i*0.85&&k>=i*0.5}else i=!1
return i},
e9(a){var t,s,r,q,p,o=A.b([],u.u)
for(t=a.length,s=0;s<a.length;a.length===t||(0,A.j)(a),++s)o.push(a[s].b)
B.a.F(o,new A.cv())
for(t=o.length,r=0,q=null,s=0;s<t;++s){p=o[s]
if(q==null||!A.bj(q,p)){++r
if(r>=3)return r
q=p}}return r},
fN(a,b){var t,s,r,q,p,o,n,m,l,k,j,i,h,g,f=A.b([],u.h)
for(t=a.length,s=b*0.8,r=t,q=0;q<r;l===t||(0,A.j)(a),++q,r=l){p=a[q]
for(o=p.b,n=o.c,m=0;l=a.length,m<l;a.length===r||(0,A.j)(a),++m){k=a[m]
if(p===k||!A.bj(o,k.b))continue
l=k.b.a
if(l-n>=s)B.a.i(f,new A.bb(n,l,o))}}for(t=f.length,s=b*0.4,r=b*0.5,q=0;q<t;++q){j=f[q]
for(o=j.b,n=j.a,l=j.c,i=0,m=0;m<t;++m){h=f[m]
if(j===h||A.bj(l,h.c))continue
g=h.b
if(Math.min(o,g)-Math.max(n,h.a)>s&&Math.abs(o-g)<r)++i}if(i>=3)return!0}return!1},
bj(a,b){var t=a.d,s=a.b,r=b.d,q=b.b,p=t-s>=r-q?a:b,o=p===a?b:a,n=o.d,m=o.b,l=n-m
if(Math.min(t,r)-Math.max(s,q)>l*0.5)return!0
t=p.d
s=p.b
r=t-s
return l<r*0.6&&n>=s-r*0.15&&m<=t},
ej(a,b){var t=a.b,s=b.d
if(!(t.d<s*0.075||t.b>s*0.925)||a.a.length>60)return""
t=A.z("\\d+",!0)
t=A.aH(a.a.toLowerCase(),t,"#")
s=A.z("\\s+",!0)
return B.b.v(A.aH(t,s," "))},
hr(a,b){var t,s,r,q,p,o,n,m,l,k=A.b([],u.V)
for(t=a.a,s=t.length,r=0;r<t.length;t.length===s||(0,A.j)(t),++r){q=t[r]
p=A.ej(q,a)
if(p.length!==0){o=!0
if(!b.J(0,p)){n=$.eF()
m=q.a
if(!n.b.test(m)){o=$.eC()
o=o.b.test(m)}}}else o=!1
if(o)continue
B.a.i(k,q)}for(l=0,t="";l<k.length;++l){q=k[l]
if(l>0)if(A.fE(k[l-1],q))t+="\u2029\n"
t+=q.a+"\n"}return t.charCodeAt(0)==0?t:t},
fE(a,b){var t,s,r,q,p,o,n,m,l=a.c,k=b.c,j=Math.max(l,k),i=j>0?Math.abs(l-k)/j:0
if(!(i>0.4))k=i>0.25&&a.a.length>=10&&b.a.length>=10
else k=!0
if(k)return!0
k=$.eJ()
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
if(!s){n=A.z("^[a-z(]",!0)
m=n.b.test(b.a)}else m=!1
if(l<p-k&&!m&&!B.b.X(t,"-")&&!B.b.X(t,","))return!0
if(s&&l<p-q*1.5)return!0
return!1},
hy(a4){var t,s,r,q,p,o,n,m,l,k,j,i,h,g,f,e,d,c,b,a,a0,a1,a2,a3=A.b([],u.U)
for(t=a4.length,s=u.y,r=u.a4,q=r.h("x<y.E>"),p=r.h("y.E"),o=u.q,n=u.t,m=0;m<a4.length;a4.length===t||(0,A.j)(a4),++m){l=a4[m]
k=A.b([],o)
for(j=B.a.gn(l);j.l();){i=j.gm()
if(B.b.v(i.a).length!==0){h=i.b
h=h.c-h.a>0&&h.d-h.b>0}else h=!1
if(h)k.push(i)}B.a.F(k,new A.cZ())
if(k.length===0)continue
j=A.b([],n)
for(i=k.length,g=0;g<k.length;k.length===i||(0,A.j)(k),++g){h=k[g].b
j.push(h.d-h.b)}f=A.W(j)
e=A.b([B.a.gO(k)],o)
for(j=new A.ao(k,1,null,r),j.az(k,1,null,s),j=new A.x(j,j.gk(0),q),k=f*1.1;j.l();){i=j.d
if(i==null)i=p.a(i)
if(i.b.a-B.a.ga_(e).b.c>k){B.a.i(a3,e)
e=A.b([i],o)}else B.a.i(e,i)}B.a.i(a3,e)}if(a3.length===0)return B.t
t=A.b([],n)
for(s=a3.length,m=0;m<a3.length;a3.length===s||(0,A.j)(a3),++m){d=a3[m]
r=A.b([],n)
for(q=B.a.gn(d);q.l();){p=q.gm().b
r.push(p.d-p.b)}t.push(A.W(r))}c=A.W(t)
b=A.b([],u.E)
for(a=0;a<a3.length;++a){d=a3[a]
s=A.u(d)
r=s.h("a(1)")
q=s.h("N<1,a>")
a0=new A.N(d,r.a(new A.d_()),q).K(0,B.h)
if(!(a<t.length))return A.f(t,a)
a1=t[a]
if(Math.abs(a1/c-1)<0.3)a1=c
p=B.a.gO(d)
a2=new A.N(d,r.a(new A.d0()),q).K(0,B.j)
B.a.i(b,new A.q(new A.N(d,s.h("d(1)").a(new A.d1()),s.h("N<1,d>")).Z(0," "),new A.l(p.b.a,a0,a2,a0+a1),a1*0.75))}return b},
l:function l(a,b,c,d){var _=this
_.a=a
_.b=b
_.c=c
_.d=d},
q:function q(a,b,c){this.a=a
this.b=b
this.c=c},
al:function al(a,b,c,d,e,f){var _=this
_.a=a
_.b=b
_.c=c
_.d=d
_.e=e
_.f=f},
a9:function a9(a,b){this.a=a
this.d=b},
cA:function cA(a,b){this.a=a
this.b=b},
cY:function cY(a,b,c,d,e){var _=this
_.a=a
_.b=b
_.c=c
_.d=d
_.e=e},
ct:function ct(){},
cu:function cu(){},
cL:function cL(a,b){this.a=a
this.b=b},
cM:function cM(a){this.a=a},
cQ:function cQ(){},
cR:function cR(){},
cN:function cN(a){this.a=a},
cP:function cP(a,b,c,d){var _=this
_.a=a
_.b=b
_.c=c
_.d=d},
cO:function cO(a){this.a=a},
cI:function cI(){},
cJ:function cJ(){},
cK:function cK(){},
cw:function cw(){},
cx:function cx(){},
cy:function cy(){},
cz:function cz(){},
cp:function cp(){},
cq:function cq(a,b){this.a=a
this.b=b},
cr:function cr(a,b){this.a=a
this.b=b},
cv:function cv(){},
H:function H(a,b){this.a=a
this.b=b},
cZ:function cZ(){},
d_:function d_(){},
d0:function d0(){},
d1:function d1(){},
hw(c5){var t,s,r,q,p,o,n,m,l,k,j,i,h,g,f,e,d,c,b,a,a0,a1,a2,a3,a4,a5,a6,a7,a8,a9,b0,b1,b2,b3,b4,b5,b6,b7,b8,b9,c0,c1,c2,c3,c4=null
try{a8=u.B
t=a8.a(B.f.aO(c5,c4))
s=A.b([],u.s)
r=A.b([],u.e)
for(a9=u.j,a8=J.bl(a9.a(J.r(t,"pages")),a8),b0=a8.$ti,a8=new A.x(a8,a8.gk(0),b0.h("x<C.E>")),b1=u.D,b2=u.H,b3=u.L,b0=b0.h("C.E"),b4=u.q,b5=u.U;a8.l();){b6=a8.d
q=b6==null?b0.a(b6):b6
p=A.V(J.r(q,"w"))
o=A.V(J.r(q,"h"))
n=b3.a(J.r(q,"ocr"))
if(n!=null){m=A.b([],b5)
for(b6=J.bl(n,a9),b7=b6.$ti,b6=new A.x(b6,b6.gk(0),b7.h("x<C.E>")),b7=b7.h("C.E");b6.l();){b8=b6.d
l=b8==null?b7.a(b8):b8
k=A.b([],b4)
for(b8=J.bl(l,a9),b9=b8.$ti,b8=new A.x(b8,b8.gk(0),b9.h("x<C.E>")),b9=b9.h("C.E");b8.l();){c0=b8.d
j=c0==null?b9.a(c0):c0
J.X(k,new A.H(A.O(J.r(j,0)),new A.l(A.V(J.r(j,1)),A.V(J.r(j,2)),A.V(J.r(j,3)),A.V(J.r(j,4)))))}J.X(m,k)}i=m
h=A.eg(A.hy(i),p,o)
b6=h.a
b7=A.u(b6)
J.X(s,new A.N(b6,b7.h("d(1)").a(new A.cX()),b7.h("N<1,d>")).Z(0,"\n"))
J.X(r,h)
continue}c1=A.dh(J.r(q,"t"))
g=c1==null?"":c1
b6=b3.a(J.r(q,"r"))
f=J.bl(b6==null?B.i:b6,b2)
e=A.V(J.r(q,"w"))
d=A.V(J.r(q,"h"))
J.X(s,g)
if(J.L(f.gI())!==J.L(g)*4||J.eP(g).length===0){J.X(r,null)
continue}c=A.b([],b1)
b=0
for(;;){b6=b
b7=J.L(g)
if(typeof b6!=="number")return b6.b6()
if(!(b6<b7))break
b6=f
b7=b
if(typeof b7!=="number")return b7.a2()
b7=b6.$ti.y[1].a(J.r(b6.a,b7*4))
b6=f
b8=b
if(typeof b8!=="number")return b8.a2()
b8=b6.$ti.y[1].a(J.r(b6.a,b8*4+1))
b6=f
b9=b
if(typeof b9!=="number")return b9.a2()
b9=b6.$ti.y[1].a(J.r(b6.a,b9*4+2))
b6=f
c0=b
if(typeof c0!=="number")return c0.a2()
J.X(c,new A.bc([b7,b8,b9,b6.$ti.y[1].a(J.r(b6.a,c0*4+3))]))
b6=b
if(typeof b6!=="number")return b6.b3()
b=b6+1}a=c
J.X(r,A.eg(A.hx(g,a,d),e,d))}A.hd(s,r)
a0=A.b([],u.r)
m=b3.a(J.r(t,"outline"))
m=J.bl(m==null?B.i:m,a9)
k=m.$ti
m=new A.x(m,m.gk(0),k.h("x<C.E>"))
k=k.h("C.E")
while(m.l()){c=m.d
a1=c==null?k.a(c):c
if(B.b.v(A.O(J.r(a1,0))).length!==0)J.X(a0,new A.ad(B.b.v(A.O(J.r(a1,0))),B.c.aZ(A.V(J.r(a1,1)))))}a2=a0
m=A.dh(J.r(t,"name"))
if(m==null)m="PDF"
a3=A.hf(s,a2,m)
m=a3.a
a4=A.b([],u.J)
for(k=a3.w,c=k.length,a0=u.N,a8=u.K,c2=0;c2<k.length;k.length===c||(0,A.j)(k),++c2){a5=k[c2]
a9=a5.a
b0=a5.b
b1=a5.c
J.X(a4,A.c5(["title",a9,"paras",b0,"pages",b1==null?B.q:b1],a0,a8))}m=B.f.aa(A.c5(["title",m,"chapters",a4],a0,a8),c4)
return m}catch(c3){m=A.dr(c3)
if(m instanceof A.aM){a6=m
m=u.N
return B.f.aa(A.c5(["error",a6.a],m,m),c4)}else{a7=m
m=u.N
m=B.f.aa(A.c5(["error","This PDF could not be read ("+A.n(a7)+")."],m,m),c4)
return m}}},
hs(){var t,s=new A.cS()
if(typeof s=="function")A.d4(A.d5("Attempting to rewrap a JS function."))
t=function(a,b){return function(c){return a(b,c,arguments.length)}}(A.fF,s)
t[$.ds()]=s
v.G.lanternPdfBook=t},
cX:function cX(){},
cS:function cS(){},
eo(a){return v.mangledGlobalNames[a]},
hF(a){throw A.A(new A.bD("Field '"+a+"' has been assigned during initialization."),new Error())},
fF(a,b,c){u.Z.a(a)
if(A.ar(c)>=1)return a.$1(b)
return a.$0()},
ei(a,b,c){A.eb(c,u.H,"T","min")
return Math.min(c.a(a),c.a(b))},
eh(a,b,c){A.eb(c,u.H,"T","max")
return Math.max(c.a(a),c.a(b))},
ee(a){var t=$.dt().aR(a)
if(t==null)t=null
else{t=t.b
if(1>=t.length)return A.f(t,1)
t=t[1]
t=t==null?null:t.length}return t==null?0:t}},B={}
var w=[A,J,B]
var $={}
A.d9.prototype={}
J.bx.prototype={
C(a,b){return a===b},
gq(a){return A.bF(a)},
j(a){return"Instance of '"+A.bG(a)+"'"},
gL(a){return A.a4(A.di(this))}}
J.bz.prototype={
j(a){return String(a)},
gq(a){return a?519018:218159},
gL(a){return A.a4(u.v)},
$ia1:1,
$ip:1}
J.aO.prototype={
C(a,b){return null==b},
j(a){return"null"},
gq(a){return 0},
$ia1:1}
J.az.prototype={$iay:1}
J.a7.prototype={
gq(a){return 0},
j(a){return String(a)}}
J.ca.prototype={}
J.a3.prototype={}
J.aQ.prototype={
j(a){var t=a[$.eq()]
if(t==null)t=a[$.ds()]
if(t==null)return this.aw(a)
return"JavaScript function for "+J.aI(t)},
$ia_:1}
J.i.prototype={
V(a,b){return new A.Y(a,A.u(a).h("@<1>").E(b).h("Y<1,2>"))},
i(a,b){A.u(a).c.a(b)
a.$flags&1&&A.av(a,29)
a.push(b)},
aW(a,b){var t
a.$flags&1&&A.av(a,"removeAt",1)
t=a.length
if(b>=t)throw A.c(A.dM(b,null))
return a.splice(b,1)[0]},
aX(a,b){A.u(a).h("p(1)").a(b)
a.$flags&1&&A.av(a,16)
this.aI(a,b,!0)},
aI(a,b,c){var t,s,r,q,p
A.u(a).h("p(1)").a(b)
t=[]
s=a.length
for(r=0;r<s;++r){q=a[r]
if(!b.$1(q))t.push(q)
if(a.length!==s)throw A.c(A.G(a))}p=t.length
if(p===s)return
this.sk(a,p)
for(r=0;r<t.length;++r)a[r]=t[r]},
U(a,b){var t
A.u(a).h("e<1>").a(b)
a.$flags&1&&A.av(a,"addAll",2)
if(Array.isArray(b)){this.aB(a,b)
return}for(t=J.bm(b);t.l();)a.push(t.gm())},
aB(a,b){var t,s
u.b.a(b)
t=b.length
if(t===0)return
if(a===b)throw A.c(A.G(a))
for(s=0;s<t;++s)a.push(b[s])},
an(a){a.$flags&1&&A.av(a,"clear","clear")
a.length=0},
Z(a,b){var t,s=A.dI(a.length,"",!1,u.N)
for(t=0;t<a.length;++t)this.A(s,t,A.n(a[t]))
return s.join(b)},
K(a,b){var t,s,r
A.u(a).h("1(1,1)").a(b)
t=a.length
if(t===0)throw A.c(A.c_())
if(0>=t)return A.f(a,0)
s=a[0]
for(r=1;r<t;++r){s=b.$2(s,a[r])
if(t!==a.length)throw A.c(A.G(a))}return s},
aT(a,b,c,d){var t,s,r
d.a(b)
A.u(a).E(d).h("1(1,2)").a(c)
t=a.length
for(s=b,r=0;r<t;++r){s=c.$2(s,a[r])
if(a.length!==t)throw A.c(A.G(a))}return s},
u(a,b){if(!(b>=0&&b<a.length))return A.f(a,b)
return a[b]},
au(a,b,c){if(b<0||b>a.length)throw A.c(A.R(b,0,a.length,"start",null))
if(c==null)c=a.length
else if(c<b||c>a.length)throw A.c(A.R(c,b,a.length,"end",null))
if(b===c)return A.b([],A.u(a))
return A.b(a.slice(b,c),A.u(a))},
gO(a){if(a.length>0)return a[0]
throw A.c(A.c_())},
ga_(a){var t=a.length
if(t>0)return a[t-1]
throw A.c(A.c_())},
aM(a,b){var t,s
A.u(a).h("p(1)").a(b)
t=a.length
for(s=0;s<t;++s){if(b.$1(a[s]))return!0
if(a.length!==t)throw A.c(A.G(a))}return!1},
F(a,b){var t,s,r,q,p,o=A.u(a)
o.h("h(1,1)?").a(b)
a.$flags&2&&A.av(a,"sort")
t=a.length
if(t<2)return
if(b==null)b=J.fR()
if(t===2){s=a[0]
r=a[1]
o=b.$2(s,r)
if(typeof o!=="number")return o.b5()
if(o>0){a[0]=r
a[1]=s}return}q=0
if(o.c.b(null))for(p=0;p<a.length;++p)if(a[p]===void 0){a[p]=null;++q}a.sort(A.hg(b,2))
if(q>0)this.aJ(a,q)},
ac(a){return this.F(a,null)},
aJ(a,b){var t,s=a.length
for(;t=s-1,s>0;s=t)if(a[t]===null){a[t]=void 0;--b
if(b===0)break}},
gp(a){return a.length===0},
gG(a){return a.length!==0},
j(a){return A.d8(a,"[","]")},
gn(a){return new J.ah(a,a.length,A.u(a).h("ah<1>"))},
gq(a){return A.bF(a)},
gk(a){return a.length},
sk(a,b){a.$flags&1&&A.av(a,"set length","change the length of")
if(b<0)throw A.c(A.R(b,0,null,"newLength",null))
if(b>a.length)A.u(a).c.a(null)
a.length=b},
D(a,b){A.ar(b)
if(!(b>=0&&b<a.length))throw A.c(A.dm(a,b))
return a[b]},
A(a,b,c){A.u(a).c.a(c)
a.$flags&2&&A.av(a)
if(!(b>=0&&b<a.length))throw A.c(A.dm(a,b))
a[b]=c},
$im:1,
$ie:1,
$io:1}
J.by.prototype={
b0(a){var t,s,r
if(!Array.isArray(a))return null
t=a.$flags|0
if((t&4)!==0)s="const, "
else if((t&2)!==0)s="unmodifiable, "
else s=(t&1)!==0?"fixed, ":""
r="Instance of '"+A.bG(a)+"'"
if(s==="")return r
return r+" ("+s+"length: "+a.length+")"}}
J.c0.prototype={}
J.ah.prototype={
gm(){var t=this.d
return t==null?this.$ti.c.a(t):t},
l(){var t,s=this,r=s.a,q=r.length
if(s.b!==q){r=A.j(r)
throw A.c(r)}t=s.c
if(t>=q){s.d=null
return!1}s.d=r[t]
s.c=t+1
return!0},
$iv:1}
J.ax.prototype={
t(a,b){var t
A.V(b)
if(a<b)return-1
else if(a>b)return 1
else if(a===b){if(a===0){t=this.gY(b)
if(this.gY(a)===t)return 0
if(this.gY(a))return-1
return 1}return 0}else if(isNaN(a)){if(isNaN(b))return 0
return 1}else return-1},
gY(a){return a===0?1/a<0:a<0},
aZ(a){var t
if(a>=-2147483648&&a<=2147483647)return a|0
if(isFinite(a)){t=a<0?Math.ceil(a):Math.floor(a)
return t+0}throw A.c(A.cg(""+a+".toInt()"))},
aN(a){var t,s
if(a>=0){if(a<=2147483647){t=a|0
return a===t?t:t+1}}else if(a>=-2147483648)return a|0
s=Math.ceil(a)
if(isFinite(s))return s
throw A.c(A.cg(""+a+".ceil()"))},
aS(a){var t,s
if(a>=0){if(a<=2147483647)return a|0}else if(a>=-2147483648){t=a|0
return a===t?t:t-1}s=Math.floor(a)
if(isFinite(s))return s
throw A.c(A.cg(""+a+".floor()"))},
M(a,b,c){if(B.d.t(b,c)>0)throw A.c(A.he(b))
if(this.t(a,b)<0)return b
if(this.t(a,c)>0)return c
return a},
a0(a,b){var t
if(b>20)throw A.c(A.R(b,0,20,"fractionDigits",null))
t=a.toFixed(b)
if(a===0&&this.gY(a))return"-"+t
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
ak(a,b){var t
if(a>0)t=this.aK(a,b)
else{t=b>31?31:b
t=a>>t>>>0}return t},
aK(a,b){return b>31?0:a>>>b},
gL(a){return A.a4(u.H)},
$iZ:1,
$ia:1,
$iE:1}
J.aN.prototype={
gL(a){return A.a4(u.S)},
$ia1:1,
$ih:1}
J.bA.prototype={
gL(a){return A.a4(u.i)},
$ia1:1}
J.a6.prototype={
a9(a,b,c){var t=b.length
if(c>t)throw A.c(A.R(c,0,t,null,null))
return new A.bV(b,a,c)},
am(a,b){return this.a9(a,b,0)},
X(a,b){var t=b.length,s=a.length
if(t>s)return!1
return b===this.av(a,s-t)},
aY(a,b,c){return A.en(a,b,c,0)},
H(a,b,c){return a.substring(b,A.f7(b,c,a.length))},
av(a,b){return this.H(a,b,null)},
v(a){var t,s,r,q=a.trim(),p=q.length
if(p===0)return q
if(0>=p)return A.f(q,0)
if(q.charCodeAt(0)===133){t=J.f3(q,1)
if(t===p)return""}else t=0
s=p-1
if(!(s>=0))return A.f(q,s)
r=q.charCodeAt(s)===133?J.dE(q,s):p
if(t===0&&r===p)return q
return q.substring(t,r)},
b_(a){var t,s=a.trimEnd(),r=s.length
if(r===0)return s
t=r-1
if(!(t>=0))return A.f(s,t)
if(s.charCodeAt(t)!==133)return s
return s.substring(0,J.dE(s,t))},
J(a,b){return A.hA(a,b,0)},
t(a,b){var t
A.O(b)
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
gL(a){return A.a4(u.N)},
gk(a){return a.length},
$ia1:1,
$iZ:1,
$ibE:1,
$id:1}
A.ac.prototype={
gn(a){return new A.aJ(J.bm(this.gI()),A.I(this).h("aJ<1,2>"))},
gk(a){return J.L(this.gI())},
gp(a){return J.eM(this.gI())},
gG(a){return J.eN(this.gI())},
j(a){return J.aI(this.gI())}}
A.aJ.prototype={
l(){return this.a.l()},
gm(){return this.$ti.y[1].a(this.a.gm())},
$iv:1}
A.ai.prototype={
gI(){return this.a}}
A.b7.prototype={$im:1}
A.b6.prototype={
D(a,b){return this.$ti.y[1].a(J.r(this.a,b))},
$im:1,
$io:1}
A.Y.prototype={
V(a,b){return new A.Y(this.a,this.$ti.h("@<1>").E(b).h("Y<1,2>"))},
gI(){return this.a}}
A.bD.prototype={
j(a){return"LateInitializationError: "+this.a}}
A.cc.prototype={}
A.m.prototype={}
A.y.prototype={
gn(a){var t=this
return new A.x(t,t.gk(t),A.I(t).h("x<y.E>"))},
gp(a){return this.gk(this)===0},
Z(a,b){var t,s,r,q=this,p=q.gk(q)
if(b.length!==0){if(p===0)return""
t=A.n(q.u(0,0))
if(p!==q.gk(q))throw A.c(A.G(q))
for(s=t,r=1;r<p;++r){s=s+b+A.n(q.u(0,r))
if(p!==q.gk(q))throw A.c(A.G(q))}return s.charCodeAt(0)==0?s:s}else{for(r=0,s="";r<p;++r){s+=A.n(q.u(0,r))
if(p!==q.gk(q))throw A.c(A.G(q))}return s.charCodeAt(0)==0?s:s}},
K(a,b){var t,s,r,q=this
A.I(q).h("y.E(y.E,y.E)").a(b)
t=q.gk(q)
if(t===0)throw A.c(A.c_())
s=q.u(0,0)
for(r=1;r<t;++r){s=b.$2(s,q.u(0,r))
if(t!==q.gk(q))throw A.c(A.G(q))}return s}}
A.ao.prototype={
az(a,b,c,d){var t,s=this.b
A.bH(s,"start")
t=this.c
if(t!=null){A.bH(t,"end")
if(s>t)throw A.c(A.R(s,0,t,"start",null))}},
gaE(){var t=J.L(this.a),s=this.c
if(s==null||s>t)return t
return s},
gaL(){var t=J.L(this.a),s=this.b
if(s>t)return t
return s},
gk(a){var t,s=J.L(this.a),r=this.b
if(r>=s)return 0
t=this.c
if(t==null||t>=s)return s-r
return t-r},
u(a,b){var t=this,s=t.gaL()+b
if(b<0||s>=t.gaE())throw A.c(A.d7(b,t.gk(0),t,"index"))
return J.dv(t.a,s)}}
A.x.prototype={
gm(){var t=this.d
return t==null?this.$ti.c.a(t):t},
l(){var t,s=this,r=s.a,q=r.gk(r)
if(s.b!==q)throw A.c(A.G(r))
t=s.c
if(t>=q){s.d=null
return!1}s.d=r.u(0,t);++s.c
return!0},
$iv:1}
A.aW.prototype={
gn(a){var t=this.a
return new A.aX(t.gn(t),this.b,A.I(this).h("aX<1,2>"))},
gk(a){var t=this.a
return t.gk(t)},
gp(a){var t=this.a
return t.gp(t)}}
A.aX.prototype={
l(){var t=this,s=t.b
if(s.l()){t.a=t.c.$1(s.gm())
return!0}t.a=null
return!1},
gm(){var t=this.a
return t==null?this.$ti.y[1].a(t):t},
$iv:1}
A.N.prototype={
gk(a){return J.L(this.a)},
u(a,b){return this.b.$1(J.dv(this.a,b))}}
A.D.prototype={
gn(a){return new A.b5(J.bm(this.a),this.b,this.$ti.h("b5<1>"))}}
A.b5.prototype={
l(){var t,s
for(t=this.a,s=this.b;t.l();)if(s.$1(t.gm()))return!0
return!1},
gm(){return this.a.gm()},
$iv:1}
A.bi.prototype={}
A.ad.prototype={$r:"+(1,2)",$s:1}
A.bb.prototype={$r:"+(1,2,3)",$s:2}
A.bc.prototype={$r:"+(1,2,3,4)",$s:3}
A.b8.prototype={
gm(){var t=this.d
return t==null?this.$ti.c.a(t):t},
l(){var t=this,s=t.c
if(s>=t.b){t.d=null
return!1}t.d=t.a[s]
t.c=s+1
return!0},
$iv:1}
A.aK.prototype={
i(a,b){A.I(this).c.a(b)
A.eY()}}
A.aL.prototype={
gk(a){return this.b},
gp(a){return this.b===0},
gG(a){return this.b!==0},
gn(a){var t,s=this,r=s.$keys
if(r==null){r=Object.keys(s.a)
s.$keys=r}t=r
return new A.b8(t,t.length,s.$ti.h("b8<1>"))}}
A.bw.prototype={
C(a,b){if(b==null)return!1
return b instanceof A.aj&&this.a.C(0,b.a)&&A.dp(this)===A.dp(b)},
gq(a){return A.c9(this.a,A.dp(this),B.e,B.e)},
j(a){var t=B.a.Z([A.a4(this.$ti.c)],", ")
return this.a.j(0)+" with "+("<"+t+">")}}
A.aj.prototype={
$2(a,b){return this.a.$1$2(a,b,this.$ti.y[0])},
$S(){return A.hq(A.cF(this.a),this.$ti)}}
A.b1.prototype={}
A.ce.prototype={
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
A.aZ.prototype={
j(a){return"Null check operator used on a null value"}}
A.bB.prototype={
j(a){var t,s=this,r="NoSuchMethodError: method not found: '",q=s.b
if(q==null)return"NoSuchMethodError: "+s.a
t=s.c
if(t==null)return r+q+"' ("+s.a+")"
return r+q+"' on '"+t+"' ("+s.a+")"}}
A.bN.prototype={
j(a){var t=this.a
return t.length===0?"Error":"Error: "+t}}
A.c8.prototype={
j(a){return"Throw of null ('"+(this.a===null?"null":"undefined")+"' from JavaScript)"}}
A.F.prototype={
j(a){var t=this.constructor,s=t==null?null:t.name
return"Closure '"+A.ep(s==null?"unknown":s)+"'"},
$ia_:1,
gb4(){return this},
$C:"$1",
$R:1,
$D:null}
A.bp.prototype={$C:"$0",$R:0}
A.bq.prototype={$C:"$2",$R:2}
A.bM.prototype={}
A.bK.prototype={
j(a){var t=this.$static_name
if(t==null)return"Closure of unknown static method"
return"Closure '"+A.ep(t)+"'"}}
A.aw.prototype={
C(a,b){if(b==null)return!1
if(this===b)return!0
if(!(b instanceof A.aw))return!1
return this.$_target===b.$_target&&this.a===b.a},
gq(a){return(A.ek(this.a)^A.bF(this.$_target))>>>0},
j(a){return"Closure '"+this.$_name+"' of "+("Instance of '"+A.bG(this.a)+"'")}}
A.bI.prototype={
j(a){return"RuntimeError: "+this.a}}
A.ak.prototype={
gk(a){return this.a},
gp(a){return this.a===0},
gN(){return new A.am(this,A.I(this).h("am<1>"))},
D(a,b){var t,s,r,q,p=null
if(typeof b=="string"){t=this.b
if(t==null)return p
s=t[b]
r=s==null?p:s.b
return r}else if(typeof b=="number"&&(b&0x3fffffff)===b){q=this.c
if(q==null)return p
s=q[b]
r=s==null?p:s.b
return r}else return this.aU(b)},
aU(a){var t,s,r=this.d
if(r==null)return null
t=this.aG(r,a)
s=this.ap(t,a)
if(s<0)return null
return t[s].b},
A(a,b,c){var t,s,r,q,p,o,n=this,m=A.I(n)
m.c.a(b)
m.y[1].a(c)
if(typeof b=="string"){t=n.b
n.ae(t==null?n.b=n.a7():t,b,c)}else if(typeof b=="number"&&(b&0x3fffffff)===b){s=n.c
n.ae(s==null?n.c=n.a7():s,b,c)}else{r=n.d
if(r==null)r=n.d=n.a7()
q=n.ao(b)
p=r[q]
if(p==null)r[q]=[n.a8(b,c)]
else{o=n.ap(p,b)
if(o>=0)p[o].b=c
else p.push(n.a8(b,c))}}},
P(a,b){var t,s,r=this
A.I(r).h("~(1,2)").a(b)
t=r.e
s=r.r
while(t!=null){b.$2(t.a,t.b)
if(s!==r.r)throw A.c(A.G(r))
t=t.c}},
ae(a,b,c){var t,s=A.I(this)
s.c.a(b)
s.y[1].a(c)
t=a[b]
if(t==null)a[b]=this.a8(b,c)
else t.b=c},
a8(a,b){var t=this,s=A.I(t),r=new A.c4(s.c.a(a),s.y[1].a(b))
if(t.e==null)t.e=t.f=r
else t.f=t.f.c=r;++t.a
t.r=t.r+1&1073741823
return r},
ao(a){return J.K(a)&1073741823},
aG(a,b){return a[this.ao(b)]},
ap(a,b){var t,s
if(a==null)return-1
t=a.length
for(s=0;s<t;++s)if(J.ag(a[s].a,b))return s
return-1},
j(a){return A.dJ(this)},
a7(){var t=Object.create(null)
t["<non-identifier-key>"]=t
delete t["<non-identifier-key>"]
return t},
$idH:1}
A.c4.prototype={}
A.am.prototype={
gk(a){return this.a.a},
gp(a){return this.a.a===0},
gn(a){var t=this.a
return new A.aU(t,t.r,t.e,this.$ti.h("aU<1>"))}}
A.aU.prototype={
gm(){return this.d},
l(){var t,s=this,r=s.a
if(s.b!==r.r)throw A.c(A.G(r))
t=s.c
if(t==null){s.d=null
return!1}else{s.d=t.a
s.c=t.c
return!0}},
$iv:1}
A.aS.prototype={
gk(a){return this.a.a},
gp(a){return this.a.a===0},
gn(a){var t=this.a
return new A.aT(t,t.r,t.e,this.$ti.h("aT<1,2>"))}}
A.aT.prototype={
gm(){var t=this.d
t.toString
return t},
l(){var t,s=this,r=s.a
if(s.b!==r.r)throw A.c(A.G(r))
t=s.c
if(t==null){s.d=null
return!1}else{s.d=new A.a8(t.a,t.b,s.$ti.h("a8<1,2>"))
s.c=t.c
return!0}},
$iv:1}
A.U.prototype={
j(a){return this.al(!1)},
al(a){var t,s,r,q,p,o=this.aF(),n=this.T(),m=(a?"Record ":"")+"("
for(t=o.length,s="",r=0;r<t;++r,s=", "){m+=s
q=o[r]
if(typeof q=="string")m=m+q+": "
if(!(r<n.length))return A.f(n,r)
p=n[r]
m=a?m+A.dL(p):m+A.n(p)}m+=")"
return m.charCodeAt(0)==0?m:m},
aF(){var t,s=this.$s
while($.cl.length<=s)B.a.i($.cl,null)
t=$.cl[s]
if(t==null){t=this.aC()
B.a.A($.cl,s,t)}return t},
aC(){var t,s,r,q=this.$r,p=q.indexOf("("),o=q.substring(1,p),n=q.substring(p),m=n==="()"?0:n.replace(/[^,]/g,"").length+1,l=A.b(new Array(m),u.f)
for(t=0;t<m;++t)l[t]=t
if(o!==""){s=o.split(",")
t=s.length
for(r=m;t>0;){--r;--t
B.a.A(l,r,s[t])}}l=A.f5(l,!1,u.K)
l.$flags=3
return l}}
A.aB.prototype={
T(){return[this.a,this.b]},
C(a,b){if(b==null)return!1
return b instanceof A.aB&&this.$s===b.$s&&J.ag(this.a,b.a)&&J.ag(this.b,b.b)},
gq(a){return A.c9(this.$s,this.a,this.b,B.e)}}
A.aC.prototype={
T(){return[this.a,this.b,this.c]},
C(a,b){var t=this
if(b==null)return!1
return b instanceof A.aC&&t.$s===b.$s&&J.ag(t.a,b.a)&&J.ag(t.b,b.b)&&J.ag(t.c,b.c)},
gq(a){var t=this
return A.c9(t.$s,t.a,t.b,t.c)}}
A.aD.prototype={
T(){return this.a},
C(a,b){if(b==null)return!1
return b instanceof A.aD&&this.$s===b.$s&&A.fl(this.a,b.a)},
gq(a){return A.c9(this.$s,A.f6(this.a),B.e,B.e)}}
A.aP.prototype={
j(a){return"RegExp/"+this.a+"/"+this.b.flags},
gai(){var t=this,s=t.c
if(s!=null)return s
s=t.b
return t.c=A.dF(t.a,s.multiline,!s.ignoreCase,s.unicode,s.dotAll,"g")},
aR(a){var t=this.b.exec(a)
if(t==null)return null
return new A.ba(t)},
a9(a,b,c){var t=b.length
if(c>t)throw A.c(A.R(c,0,t,null,null))
return new A.bO(this,b,c)},
am(a,b){return this.a9(0,b,0)},
ag(a,b){var t,s=this.gai()
if(s==null)s=A.dg(s)
s.lastIndex=b
t=s.exec(a)
if(t==null)return null
return new A.ba(t)},
$ibE:1,
$icb:1}
A.ba.prototype={
gad(){return this.b.index},
gW(){var t=this.b
return t.index+t[0].length},
$iaA:1,
$ib0:1}
A.bO.prototype={
gn(a){return new A.bP(this.a,this.b,this.c)}}
A.bP.prototype={
gm(){var t=this.d
return t==null?u.a0.a(t):t},
l(){var t,s,r,q,p,o,n=this,m=n.b
if(m==null)return!1
t=n.c
s=m.length
if(t<=s){r=n.a
q=r.ag(m,t)
if(q!=null){n.d=q
p=q.gW()
if(q.b.index===p){t=!1
if(r.b.unicode){r=n.c
o=r+1
if(o<s){if(!(r>=0&&r<s))return A.f(m,r)
r=m.charCodeAt(r)
if(r>=55296&&r<=56319){if(!(o>=0))return A.f(m,o)
t=m.charCodeAt(o)
t=t>=56320&&t<=57343}}}p=(t?p+1:p)+1}n.c=p
return!0}}n.b=n.d=null
return!1},
$iv:1}
A.bL.prototype={
gW(){return this.a+this.c.length},
$iaA:1,
gad(){return this.a}}
A.bV.prototype={
gn(a){return new A.bW(this.a,this.b,this.c)}}
A.bW.prototype={
l(){var t,s,r=this,q=r.c,p=r.b,o=p.length,n=r.a,m=n.length
if(q+o>m){r.d=null
return!1}t=n.indexOf(p,q)
if(t<0){r.c=m+1
r.d=null
return!1}s=t+o
r.d=new A.bL(t,p)
r.c=s===r.c?s+1:s
return!0},
gm(){var t=this.d
t.toString
return t},
$iv:1}
A.T.prototype={
h(a){return A.bh(v.typeUniverse,this,a)},
E(a){return A.dZ(v.typeUniverse,this,a)}}
A.bR.prototype={}
A.cm.prototype={
j(a){return A.J(this.a,null)}}
A.bQ.prototype={
j(a){return this.a}}
A.aE.prototype={}
A.b9.prototype={
gn(a){var t=this,s=new A.ap(t,t.r,t.$ti.h("ap<1>"))
s.c=t.e
return s},
gk(a){return this.a},
gp(a){return this.a===0},
gG(a){return this.a!==0},
J(a,b){var t,s
if(typeof b=="string"&&b!=="__proto__"){t=this.b
if(t==null)return!1
return u.M.a(t[b])!=null}else{s=this.aD(b)
return s}},
aD(a){var t=this.d
if(t==null)return!1
return this.ah(t[J.K(a)&1073741823],a)>=0},
i(a,b){var t,s,r=this
r.$ti.c.a(b)
if(typeof b=="string"&&b!=="__proto__"){t=r.b
return r.af(t==null?r.b=A.dc():t,b)}else if(typeof b=="number"&&(b&1073741823)===b){s=r.c
return r.af(s==null?r.c=A.dc():s,b)}else return r.aA(b)},
aA(a){var t,s,r,q=this
q.$ti.c.a(a)
t=q.d
if(t==null)t=q.d=A.dc()
s=J.K(a)&1073741823
r=t[s]
if(r==null)t[s]=[q.a4(a)]
else{if(q.ah(r,a)>=0)return!1
r.push(q.a4(a))}return!0},
af(a,b){this.$ti.c.a(b)
if(u.M.a(a[b])!=null)return!1
a[b]=this.a4(b)
return!0},
a4(a){var t=this,s=new A.bU(t.$ti.c.a(a))
if(t.e==null)t.e=t.f=s
else t.f=t.f.b=s;++t.a
t.r=t.r+1&1073741823
return s},
ah(a,b){var t,s
if(a==null)return-1
t=a.length
for(s=0;s<t;++s)if(J.ag(a[s].a,b))return s
return-1}}
A.bU.prototype={}
A.ap.prototype={
gm(){var t=this.d
return t==null?this.$ti.c.a(t):t},
l(){var t=this,s=t.c,r=t.a
if(t.b!==r.r)throw A.c(A.G(r))
else if(s==null){t.d=null
return!1}else{t.d=t.$ti.h("1?").a(s.a)
t.c=s.b
return!0}},
$iv:1}
A.C.prototype={
gn(a){return new A.x(this,this.gk(0),this.$ti.h("x<C.E>"))},
u(a,b){return this.$ti.y[1].a(J.r(this.a,b))},
gp(a){return J.L(this.a)===0},
gG(a){return J.L(this.a)!==0},
V(a,b){return new A.Y(this,this.$ti.h("@<C.E>").E(b).h("Y<1,2>"))},
j(a){return A.d8(this,"[","]")}}
A.M.prototype={
P(a,b){var t,s,r,q=A.I(this)
q.h("~(M.K,M.V)").a(b)
for(t=this.gN(),t=t.gn(t),q=q.h("M.V");t.l();){s=t.gm()
r=this.D(0,s)
b.$2(s,r==null?q.a(r):r)}},
gk(a){var t=this.gN()
return t.gk(t)},
gp(a){var t=this.gN()
return t.gp(t)},
j(a){return A.dJ(this)},
$iaV:1}
A.c7.prototype={
$2(a,b){var t,s=this.a
if(!s.a)this.b.a+=", "
s.a=!1
s=this.b
t=A.n(a)
s.a=(s.a+=t)+": "
t=A.n(b)
s.a+=t},
$S:3}
A.aa.prototype={
gp(a){return this.gk(this)===0},
gG(a){return this.gk(this)!==0},
U(a,b){var t,s
A.I(this).h("e<1>").a(b)
for(t=b.length,s=0;s<b.length;b.length===t||(0,A.j)(b),++s)this.i(0,b[s])},
j(a){return A.d8(this,"{","}")},
$im:1,
$ie:1}
A.bd.prototype={}
A.bS.prototype={
D(a,b){var t,s=this.b
if(s==null)return this.c.D(0,b)
else if(typeof b!="string")return null
else{t=s[b]
return typeof t=="undefined"?this.aH(b):t}},
gk(a){return this.b==null?this.c.a:this.S().length},
gp(a){return this.gk(0)===0},
gN(){if(this.b==null){var t=this.c
return new A.am(t,A.I(t).h("am<1>"))}return new A.bT(this)},
P(a,b){var t,s,r,q,p=this
u.cQ.a(b)
if(p.b==null)return p.c.P(0,b)
t=p.S()
for(s=0;s<t.length;++s){r=t[s]
q=p.b[r]
if(typeof q=="undefined"){q=A.cs(p.a[r])
p.b[r]=q}b.$2(r,q)
if(t!==p.c)throw A.c(A.G(p))}},
S(){var t=u.L.a(this.c)
if(t==null)t=this.c=A.b(Object.keys(this.a),u.s)
return t},
aH(a){var t
if(!Object.prototype.hasOwnProperty.call(this.a,a))return null
t=A.cs(this.a[a])
return this.b[a]=t}}
A.bT.prototype={
gk(a){return this.a.gk(0)},
u(a,b){var t=this.a
if(t.b==null)t=t.gN().u(0,b)
else{t=t.S()
if(!(b>=0&&b<t.length))return A.f(t,b)
t=t[b]}return t},
gn(a){var t=this.a
if(t.b==null){t=t.gN()
t=t.gn(t)}else{t=t.S()
t=new J.ah(t,t.length,A.u(t).h("ah<1>"))}return t}}
A.br.prototype={}
A.bt.prototype={}
A.aR.prototype={
j(a){var t=A.bu(this.a)
return(this.b!=null?"Converting object to an encodable object failed:":"Converting object did not return an encodable object:")+" "+t}}
A.bC.prototype={
j(a){return"Cyclic error in JSON stringify"}}
A.c1.prototype={
aO(a,b){var t=A.h4(a,this.gaP().a)
return t},
aa(a,b){var t=A.fc(a,this.gaQ().b,null)
return t},
gaQ(){return B.p},
gaP(){return B.o}}
A.c3.prototype={}
A.c2.prototype={}
A.cj.prototype={
ar(a){var t,s,r,q,p,o,n=a.length
for(t=this.c,s=0,r=0;r<n;++r){q=a.charCodeAt(r)
if(q>92){if(q>=55296){p=q&64512
if(p===55296){o=r+1
o=!(o<n&&(a.charCodeAt(o)&64512)===56320)}else o=!1
if(!o)if(p===56320){p=r-1
p=!(p>=0&&(a.charCodeAt(p)&64512)===55296)}else p=!1
else p=!0
if(p){if(r>s)t.a+=B.b.H(a,s,r)
s=r+1
p=A.B(92)
t.a+=p
p=A.B(117)
t.a+=p
p=A.B(100)
t.a+=p
p=q>>>8&15
p=A.B(p<10?48+p:87+p)
t.a+=p
p=q>>>4&15
p=A.B(p<10?48+p:87+p)
t.a+=p
p=q&15
p=A.B(p<10?48+p:87+p)
t.a+=p}}continue}if(q<32){if(r>s)t.a+=B.b.H(a,s,r)
s=r+1
p=A.B(92)
t.a+=p
switch(q){case 8:p=A.B(98)
t.a+=p
break
case 9:p=A.B(116)
t.a+=p
break
case 10:p=A.B(110)
t.a+=p
break
case 12:p=A.B(102)
t.a+=p
break
case 13:p=A.B(114)
t.a+=p
break
default:p=A.B(117)
t.a+=p
p=A.B(48)
t.a=(t.a+=p)+p
p=q>>>4&15
p=A.B(p<10?48+p:87+p)
t.a+=p
p=q&15
p=A.B(p<10?48+p:87+p)
t.a+=p
break}}else if(q===34||q===92){if(r>s)t.a+=B.b.H(a,s,r)
s=r+1
p=A.B(92)
t.a+=p
p=A.B(q)
t.a+=p}}if(s===0)t.a+=a
else if(s<n)t.a+=B.b.H(a,s,n)},
a3(a){var t,s,r,q
for(t=this.a,s=t.length,r=0;r<s;++r){q=t[r]
if(a==null?q==null:a===q)throw A.c(new A.bC(a,null))}B.a.i(t,a)},
a1(a){var t,s,r,q,p=this
if(p.aq(a))return
p.a3(a)
try{t=p.b.$1(a)
if(!p.aq(t)){r=A.dG(a,null,p.gaj())
throw A.c(r)}r=p.a
if(0>=r.length)return A.f(r,-1)
r.pop()}catch(q){s=A.dr(q)
r=A.dG(a,s,p.gaj())
throw A.c(r)}},
aq(a){var t,s,r=this
if(typeof a=="number"){if(!isFinite(a))return!1
r.c.a+=B.c.j(a)
return!0}else if(a===!0){r.c.a+="true"
return!0}else if(a===!1){r.c.a+="false"
return!0}else if(a==null){r.c.a+="null"
return!0}else if(typeof a=="string"){t=r.c
t.a+='"'
r.ar(a)
t.a+='"'
return!0}else if(u.j.b(a)){r.a3(a)
r.b1(a)
t=r.a
if(0>=t.length)return A.f(t,-1)
t.pop()
return!0}else if(a instanceof A.M){r.a3(a)
s=r.b2(a)
t=r.a
if(0>=t.length)return A.f(t,-1)
t.pop()
return s}else return!1},
b1(a){var t,s,r=this.c
r.a+="["
t=J.bX(a)
if(t.gG(a)){this.a1(t.D(a,0))
for(s=1;s<t.gk(a);++s){r.a+=","
this.a1(t.D(a,s))}}r.a+="]"},
b2(a){var t,s,r,q,p,o,n=this,m={}
if(a.gp(a)){n.c.a+="{}"
return!0}t=a.gk(a)*2
s=A.dI(t,null,!1,u.O)
r=m.a=0
m.b=!0
a.P(0,new A.ck(m,s))
if(!m.b)return!1
q=n.c
q.a+="{"
for(p='"';r<t;r+=2,p=',"'){q.a+=p
n.ar(A.O(s[r]))
q.a+='":'
o=r+1
if(!(o<t))return A.f(s,o)
n.a1(s[o])}q.a+="}"
return!0}}
A.ck.prototype={
$2(a,b){var t,s
if(typeof a!="string")this.a.b=!1
t=this.b
s=this.a
B.a.A(t,s.a++,a)
B.a.A(t,s.a++,b)},
$S:3}
A.ci.prototype={
gaj(){var t=this.c.a
return t.charCodeAt(0)==0?t:t}}
A.t.prototype={}
A.bn.prototype={
j(a){var t=this.a
if(t!=null)return"Assertion failed: "+A.bu(t)
return"Assertion failed"}}
A.b3.prototype={}
A.a5.prototype={
ga6(){return"Invalid argument"+(!this.a?"(s)":"")},
ga5(){return""},
j(a){var t=this,s=t.c,r=s==null?"":" ("+s+")",q=t.d,p=q==null?"":": "+q,o=t.ga6()+r+p
if(!t.a)return o
return o+t.ga5()+": "+A.bu(t.gab())},
gab(){return this.b}}
A.b_.prototype={
gab(){return A.e1(this.b)},
ga6(){return"RangeError"},
ga5(){var t,s=this.e,r=this.f
if(s==null)t=r!=null?": Not less than or equal to "+A.n(r):""
else if(r==null)t=": Not greater than or equal to "+A.n(s)
else if(r>s)t=": Not in inclusive range "+A.n(s)+".."+A.n(r)
else t=r<s?": Valid value range is empty":": Only valid value is "+A.n(s)
return t}}
A.bv.prototype={
gab(){return A.ar(this.b)},
ga6(){return"RangeError"},
ga5(){if(A.ar(this.b)<0)return": index must not be negative"
var t=this.f
if(t===0)return": no indices are valid"
return": index should be less than "+t},
gk(a){return this.f}}
A.b4.prototype={
j(a){return"Unsupported operation: "+this.a}}
A.bJ.prototype={
j(a){return"Bad state: "+this.a}}
A.bs.prototype={
j(a){var t=this.a
if(t==null)return"Concurrent modification during iteration."
return"Concurrent modification during iteration: "+A.bu(t)+"."}}
A.b2.prototype={
j(a){return"Stack Overflow"},
$it:1}
A.ch.prototype={
j(a){return"Exception: "+this.a}}
A.aM.prototype={
j(a){var t=this.a,s=""!==t?"FormatException: "+t:"FormatException",r=this.b
if(typeof r=="string"){if(r.length>78)r=B.b.H(r,0,75)+"..."
return s+"\n"+r}else return s}}
A.e.prototype={
V(a,b){return A.eS(this,A.I(this).h("e.E"),b)},
gk(a){var t,s=this.gn(this)
for(t=0;s.l();)++t
return t},
gp(a){return!this.gn(this).l()},
gG(a){return!this.gp(this)},
u(a,b){var t,s
A.bH(b,"index")
t=this.gn(this)
for(s=b;t.l();){if(s===0)return t.gm();--s}throw A.c(A.d7(b,b-s,this,"index"))},
j(a){return A.eZ(this,"(",")")}}
A.a8.prototype={
j(a){return"MapEntry("+A.n(this.a)+": "+A.n(this.b)+")"}}
A.aY.prototype={
gq(a){return A.k.prototype.gq.call(this,0)},
j(a){return"null"}}
A.k.prototype={$ik:1,
C(a,b){return this===b},
gq(a){return A.bF(this)},
j(a){return"Instance of '"+A.bG(this)+"'"},
gL(a){return A.hn(this)},
toString(){return this.j(this)}}
A.ab.prototype={
gk(a){return this.a.length},
j(a){var t=this.a
return t.charCodeAt(0)==0?t:t},
$if9:1}
A.Q.prototype={
saV(a){this.c=u.cl.a(a)}}
A.bZ.prototype={}
A.d2.prototype={
$1(a){return A.ee(A.O(a))===this.a},
$S:0}
A.d3.prototype={
$1(a){u.d.a(a)
return a.b.length===0&&this.a.length>1&&a.a===this.b},
$S:10}
A.cT.prototype={
$1(a){return B.b.J(A.O(a),"\u2029")},
$S:0}
A.cU.prototype={
$1(a){return A.O(a).length>20},
$S:0}
A.cV.prototype={
$1(a){return A.O(a).length},
$S:11}
A.cW.prototype={
$0(){var t=this,s=t.b,r=s.a,q=B.b.v(r.charCodeAt(0)==0?r:r)
s.a=""
if(q.length!==0){B.a.i(t.c,q)
B.a.i(t.d,t.a.a)}},
$S:4}
A.cB.prototype={
$1(a){return u.cM.a(a)!=null},
$S:12}
A.cC.prototype={
$2(a,b){return A.ar(a)+B.b.v(A.O(b)).length},
$S:13}
A.cD.prototype={
$2(a,b){var t=u.x
return B.d.t(t.a(a).b,t.a(b).b)},
$S:14}
A.cE.prototype={
$3(a,b,c){var t
A.ar(c)
t=A.b([],u.X)
return new A.Q(a,A.el(B.a.au(this.a,b,c),b,t),t)},
$S:15}
A.l.prototype={
R(a){var t=this
return new A.l(Math.min(t.a,a.a),Math.min(t.b,a.b),Math.max(t.c,a.c),Math.max(t.d,a.d))},
j(a){var t=this
return"LRect("+B.c.a0(t.a,1)+", "+B.c.a0(t.b,1)+", "+B.c.a0(t.c,1)+", "+B.c.a0(t.d,1)+")"}}
A.q.prototype={}
A.al.prototype={}
A.a9.prototype={}
A.cA.prototype={
$1(a){var t,s,r,q,p,o=A.b([],u.t)
for(t=this.a,s=a.b,r=this.b,q=0;q<t.length;++q){p=t[q]
if(s.test(p)){if(!(q<r.length))return A.f(r,q)
o.push(r[q])}}return o},
$S:16}
A.cY.prototype={
$0(){var t=this,s=t.b,r=s.a,q=A.z("[\\s\xa0]+",!0),p=B.b.v(A.aH(r.charCodeAt(0)==0?r:r,q," "))
if(p.length!==0&&t.a.a!=null){r=t.a.a
r.toString
B.a.i(t.c,new A.q(p,r,A.h7(t.d,t.e)))}s.a=""
t.a.a=null
B.a.an(t.e)
B.a.an(t.d)},
$S:4}
A.ct.prototype={
$2(a,b){var t=u.n
return B.c.t(t.a(a).b.b,t.a(b).b.b)},
$S:1}
A.cu.prototype={
$2(a,b){var t=u.o
return B.c.t(t.a(a).a,t.a(b).a)},
$S:17}
A.cL.prototype={
$2(a,b){var t,s,r,q,p,o,n,m,l,k,j,i,h,g,f=this
u.Y.a(a)
if(a.length<=1||b>60){B.a.i(f.a,a)
return}t=A.b([],u.u)
for(s=a.length,r=0;r<a.length;a.length===s||(0,A.j)(a),++r)t.push(a[r].b)
s=A.e4(t,!0)
q=f.b
p=A.u(s)
o=p.h("D<1>")
n=A.an(new A.D(s,p.h("p(1)").a(new A.cM(q)),o),o.h("e.E"))
m=A.e4(t,!1)
t=new A.cQ()
l=t.$1(n)
s=A.u(m)
p=s.h("p(1)")
s=s.h("D<1>")
o=s.h("e.E")
k=A.an(new A.D(m,p.a(new A.cN(q)),s),o)
j=t.$1(k)
k=new A.cP(a,q,f,b)
i=l!=null
if(i)h=j==null||j.b-j.a<q*2.5
else h=!1
if(h)if(k.$2(l,!0))return
if(j!=null&&k.$2(j,!1))return
if(i&&k.$2(l,!0))return
s=A.an(new A.D(m,p.a(new A.cO(q)),s),o)
g=t.$1(s)
if(g!=null&&A.fN(a,q)&&k.$2(g,!1))return
B.a.i(f.a,a)},
$S:18}
A.cM.prototype={
$1(a){u.o.a(a)
return a.b-a.a>=this.a*0.8},
$S:2}
A.cQ.prototype={
$1(a){u.l.a(a)
return a.length===0?null:B.a.K(a,new A.cR())},
$S:19}
A.cR.prototype={
$2(a,b){var t=u.o
t.a(a)
t.a(b)
return b.b-b.a>a.b-a.a?b:a},
$S:20}
A.cN.prototype={
$1(a){u.o.a(a)
return a.b-a.a>=this.a*1.6},
$S:2}
A.cP.prototype={
$2(a,b){var t,s,r,q,p=this,o=(a.a+a.b)/2,n=u.E,m=A.b([],n),l=A.b([],n)
for(n=p.a,t=n.length,s=0;s<n.length;n.length===t||(0,A.j)(n),++s){r=n[s]
q=r.b
B.a.i((b?q.c:q.d)<=o?m:l,r)}if(m.length===0||l.length===0)return!1
if(b)n=A.e9(m)<3||A.e9(l)<3||!A.fw(l,p.b)
else n=!1
if(n)return!1
n=p.c
t=p.d+1
n.$2(m,t)
n.$2(l,t)
return!0},
$S:21}
A.cO.prototype={
$1(a){u.o.a(a)
return a.b-a.a>=this.a*0.25},
$S:2}
A.cI.prototype={
$2(a,b){var t=u.n,s=t.a(a).b
t=t.a(b).b
if(A.bj(s,t))return B.c.t(s.a,t.a)
return B.c.t(s.b+s.d,t.b+t.d)},
$S:1}
A.cJ.prototype={
$1(a){return u.n.a(a).b},
$S:5}
A.cK.prototype={
$2(a,b){var t=u.R
return t.a(a).R(t.a(b))},
$S:6}
A.cw.prototype={
$1(a){var t
u.Y.a(a)
t=A.u(a)
return new A.N(a,t.h("l(1)").a(new A.cx()),t.h("N<1,l>")).K(0,new A.cy())},
$S:22}
A.cx.prototype={
$1(a){return u.n.a(a).b},
$S:5}
A.cy.prototype={
$2(a,b){var t=u.R
return t.a(a).R(t.a(b))},
$S:6}
A.cz.prototype={
$1(a){var t,s,r
u.Y.a(a)
t=A.b([],u.t)
for(s=a.length,r=0;r<a.length;a.length===s||(0,A.j)(a),++r)t.push(a[r].c)
return A.W(t)},
$S:23}
A.cp.prototype={
$2(a,b){var t=u.n
return B.c.t(t.a(a).b.b,t.a(b).b.b)},
$S:1}
A.cq.prototype={
$1(a){return A.df(a)-this.a<this.b*0.5},
$S:7}
A.cr.prototype={
$1(a){var t=A.df(a)-this.a,s=this.b
return t>=s*0.5&&t<s*3.5},
$S:7}
A.cv.prototype={
$2(a,b){var t=u.R
return B.c.t(t.a(a).b,t.a(b).b)},
$S:24}
A.H.prototype={}
A.cZ.prototype={
$2(a,b){var t=u.y
return B.c.t(t.a(a).b.a,t.a(b).b.a)},
$S:25}
A.d_.prototype={
$1(a){return u.y.a(a).b.b},
$S:8}
A.d0.prototype={
$1(a){return u.y.a(a).b.c},
$S:8}
A.d1.prototype={
$1(a){return B.b.v(u.y.a(a).a)},
$S:26}
A.cX.prototype={
$1(a){return u.k.a(a).a},
$S:27}
A.cS.prototype={
$1(a){return A.hw(A.O(a))},
$S:28};(function aliases(){var t=J.a7.prototype
t.aw=t.j})();(function installTearOffs(){var t=hunkHelpers._static_2,s=hunkHelpers._static_1,r=hunkHelpers.installStaticTearOff
t(J,"fR","f2",29)
s(A,"hi","fG",30)
r(A,"hu",2,null,["$1$2","$2"],["ei",function(a,b){return A.ei(a,b,u.H)}],9,0)
r(A,"ht",2,null,["$1$2","$2"],["eh",function(a,b){return A.eh(a,b,u.H)}],9,0)})();(function inheritance(){var t=hunkHelpers.mixin,s=hunkHelpers.inherit,r=hunkHelpers.inheritMany
s(A.k,null)
r(A.k,[A.d9,J.bx,A.b1,J.ah,A.e,A.aJ,A.t,A.cc,A.x,A.aX,A.b5,A.U,A.b8,A.aa,A.F,A.ce,A.c8,A.M,A.c4,A.aU,A.aT,A.aP,A.ba,A.bP,A.bL,A.bW,A.T,A.bR,A.cm,A.bU,A.ap,A.C,A.br,A.bt,A.cj,A.b2,A.ch,A.aM,A.a8,A.aY,A.ab,A.Q,A.bZ,A.l,A.q,A.al,A.a9,A.H])
r(J.bx,[J.bz,J.aO,J.az,J.ax,J.a6])
r(J.az,[J.a7,J.i])
r(J.a7,[J.ca,J.a3,J.aQ])
s(J.by,A.b1)
s(J.c0,J.i)
r(J.ax,[J.aN,J.bA])
r(A.e,[A.ac,A.m,A.aW,A.D,A.bO,A.bV])
r(A.ac,[A.ai,A.bi])
s(A.b7,A.ai)
s(A.b6,A.bi)
s(A.Y,A.b6)
r(A.t,[A.bD,A.b3,A.bB,A.bN,A.bI,A.bQ,A.aR,A.bn,A.a5,A.b4,A.bJ,A.bs])
r(A.m,[A.y,A.am,A.aS])
r(A.y,[A.ao,A.N,A.bT])
r(A.U,[A.aB,A.aC,A.aD])
s(A.ad,A.aB)
s(A.bb,A.aC)
s(A.bc,A.aD)
r(A.aa,[A.aK,A.bd])
s(A.aL,A.aK)
r(A.F,[A.bw,A.bp,A.bq,A.bM,A.d2,A.d3,A.cT,A.cU,A.cV,A.cB,A.cE,A.cA,A.cM,A.cQ,A.cN,A.cO,A.cJ,A.cw,A.cx,A.cz,A.cq,A.cr,A.d_,A.d0,A.d1,A.cX,A.cS])
s(A.aj,A.bw)
s(A.aZ,A.b3)
r(A.bM,[A.bK,A.aw])
r(A.M,[A.ak,A.bS])
s(A.aE,A.bQ)
s(A.b9,A.bd)
r(A.bq,[A.c7,A.ck,A.cC,A.cD,A.ct,A.cu,A.cL,A.cR,A.cP,A.cI,A.cK,A.cy,A.cp,A.cv,A.cZ])
s(A.bC,A.aR)
s(A.c1,A.br)
r(A.bt,[A.c3,A.c2])
s(A.ci,A.cj)
r(A.a5,[A.b_,A.bv])
r(A.bp,[A.cW,A.cY])
t(A.bi,A.C)})()
var v={G:typeof self!="undefined"?self:globalThis,typeUniverse:{eC:new Map(),tR:{},eT:{},tPV:{},sEA:[]},mangledGlobalNames:{h:"int",a:"double",E:"num",d:"String",p:"bool",aY:"Null",o:"List",k:"Object",aV:"Map",ay:"JSObject"},mangledNames:{},types:["p(d)","h(q,q)","p(+(a,a))","~(k?,k?)","~()","l(q)","l(l,l)","p(a)","a(H)","0^(0^,0^)<E>","p(Q)","h(d)","p(a9?)","h(h,d)","h(+(d,h),+(d,h))","Q(d,h,h)","o<a>(cb)","h(+(a,a),+(a,a))","~(o<q>,h)","+(a,a)?(o<+(a,a)>)","+(a,a)(+(a,a),+(a,a))","p(+(a,a),p)","l(o<q>)","a(o<q>)","h(l,l)","h(H,H)","d(H)","d(al)","d(d)","h(@,@)","@(@)"],arrayRti:Symbol("$ti"),rttc:{"2;":(a,b)=>c=>c instanceof A.ad&&a.b(c.a)&&b.b(c.b),"3;":(a,b,c)=>d=>d instanceof A.bb&&a.b(d.a)&&b.b(d.b)&&c.b(d.c),"4;":a=>b=>b instanceof A.bc&&A.hv(a,b.a)}}
A.ft(v.typeUniverse,JSON.parse('{"aQ":"a7","ca":"a7","a3":"a7","bz":{"p":[],"a1":[]},"aO":{"a1":[]},"az":{"ay":[]},"a7":{"ay":[]},"i":{"o":["1"],"m":["1"],"ay":[],"e":["1"]},"by":{"b1":[]},"c0":{"i":["1"],"o":["1"],"m":["1"],"ay":[],"e":["1"]},"ah":{"v":["1"]},"ax":{"a":[],"E":[],"Z":["E"]},"aN":{"a":[],"h":[],"E":[],"Z":["E"],"a1":[]},"bA":{"a":[],"E":[],"Z":["E"],"a1":[]},"a6":{"d":[],"Z":["d"],"bE":[],"a1":[]},"ac":{"e":["2"]},"aJ":{"v":["2"]},"ai":{"ac":["1","2"],"e":["2"],"e.E":"2"},"b7":{"ai":["1","2"],"ac":["1","2"],"m":["2"],"e":["2"],"e.E":"2"},"b6":{"C":["2"],"o":["2"],"ac":["1","2"],"m":["2"],"e":["2"]},"Y":{"b6":["1","2"],"C":["2"],"o":["2"],"ac":["1","2"],"m":["2"],"e":["2"],"C.E":"2","e.E":"2"},"bD":{"t":[]},"m":{"e":["1"]},"y":{"m":["1"],"e":["1"]},"ao":{"y":["1"],"m":["1"],"e":["1"],"y.E":"1","e.E":"1"},"x":{"v":["1"]},"aW":{"e":["2"],"e.E":"2"},"aX":{"v":["2"]},"N":{"y":["2"],"m":["2"],"e":["2"],"y.E":"2","e.E":"2"},"D":{"e":["1"],"e.E":"1"},"b5":{"v":["1"]},"ad":{"aB":[],"U":[]},"bb":{"aC":[],"U":[]},"bc":{"aD":[],"U":[]},"b8":{"v":["1"]},"aK":{"aa":["1"],"m":["1"],"e":["1"]},"aL":{"aK":["1"],"aa":["1"],"m":["1"],"e":["1"]},"bw":{"F":[],"a_":[]},"aj":{"F":[],"a_":[]},"aZ":{"t":[]},"bB":{"t":[]},"bN":{"t":[]},"F":{"a_":[]},"bp":{"F":[],"a_":[]},"bq":{"F":[],"a_":[]},"bM":{"F":[],"a_":[]},"bK":{"F":[],"a_":[]},"aw":{"F":[],"a_":[]},"bI":{"t":[]},"ak":{"M":["1","2"],"dH":["1","2"],"aV":["1","2"],"M.K":"1","M.V":"2"},"am":{"m":["1"],"e":["1"],"e.E":"1"},"aU":{"v":["1"]},"aS":{"m":["a8<1,2>"],"e":["a8<1,2>"],"e.E":"a8<1,2>"},"aT":{"v":["a8<1,2>"]},"aB":{"U":[]},"aC":{"U":[]},"aD":{"U":[]},"aP":{"cb":[],"bE":[]},"ba":{"b0":[],"aA":[]},"bO":{"e":["b0"],"e.E":"b0"},"bP":{"v":["b0"]},"bL":{"aA":[]},"bV":{"e":["aA"],"e.E":"aA"},"bW":{"v":["aA"]},"bQ":{"t":[]},"aE":{"t":[]},"b9":{"aa":["1"],"m":["1"],"e":["1"]},"ap":{"v":["1"]},"M":{"aV":["1","2"]},"aa":{"m":["1"],"e":["1"]},"bd":{"aa":["1"],"m":["1"],"e":["1"]},"bS":{"M":["d","@"],"aV":["d","@"],"M.K":"d","M.V":"@"},"bT":{"y":["d"],"m":["d"],"e":["d"],"y.E":"d","e.E":"d"},"aR":{"t":[]},"bC":{"t":[]},"a":{"E":[],"Z":["E"]},"h":{"E":[],"Z":["E"]},"o":{"m":["1"],"e":["1"]},"E":{"Z":["E"]},"cb":{"bE":[]},"b0":{"aA":[]},"d":{"Z":["d"],"bE":[]},"bn":{"t":[]},"b3":{"t":[]},"a5":{"t":[]},"b_":{"t":[]},"bv":{"t":[]},"b4":{"t":[]},"bJ":{"t":[]},"bs":{"t":[]},"b2":{"t":[]},"ab":{"f9":[]}}'))
A.fs(v.typeUniverse,JSON.parse('{"bi":2,"bd":1,"br":2,"bt":2}'))
var u=(function rtii(){var t=A.cG
return{W:t("Z<@>"),_:t("m<@>"),C:t("t"),Z:t("a_"),d:t("Q"),w:t("aj<a>"),a:t("e<@>"),p:t("i<Q>"),V:t("i<al>"),u:t("i<l>"),E:t("i<q>"),c:t("i<o<q>>"),U:t("i<o<H>>"),J:t("i<aV<d,k>>"),f:t("i<k>"),q:t("i<H>"),r:t("i<+(d,h)>"),G:t("i<+(a,a)>"),h:t("i<+(a,a,l)>"),D:t("i<+(a,a,a,a)>"),s:t("i<d>"),t:t("i<a>"),b:t("i<@>"),X:t("i<h>"),e:t("i<a9?>"),T:t("aO"),m:t("ay"),g:t("aQ"),k:t("al"),R:t("l"),A:t("l(q)"),n:t("q"),Y:t("o<q>"),l:t("o<+(a,a)>"),j:t("o<@>"),B:t("aV<d,@>"),bw:t("aW<d,h>"),aR:t("N<q,l>"),P:t("aY"),K:t("k"),y:t("H"),cY:t("hK"),F:t("+()"),x:t("+(d,h)"),o:t("+(a,a)"),a0:t("b0"),N:t("d"),a4:t("ao<H>"),bW:t("a1"),cr:t("a3"),z:t("D<d>"),bL:t("D<a>"),v:t("p"),Q:t("p(d)"),ax:t("p(a)"),i:t("a"),S:t("h"),bv:t("h(d)"),bc:t("dC<aY>?"),aQ:t("ay?"),L:t("o<@>?"),cl:t("o<h>?"),O:t("k?"),cM:t("a9?"),aD:t("d?"),M:t("bU?"),cG:t("p?"),I:t("a?"),a3:t("h?"),ae:t("E?"),H:t("E"),cQ:t("~(d,@)")}})();(function constants(){var t=hunkHelpers.makeConstList
B.m=J.bx.prototype
B.a=J.i.prototype
B.d=J.aN.prototype
B.c=J.ax.prototype
B.b=J.a6.prototype
B.n=J.az.prototype
B.j=new A.aj(A.ht(),u.w)
B.h=new A.aj(A.hu(),u.w)
B.k=function getTagFallback(o) {
  var s = Object.prototype.toString.call(o);
  return s.substring(8, s.length - 1);
}
B.f=new A.c1()
B.e=new A.cc()
B.l=new A.aM("This PDF has no text layer (it looks like scanned pages), so it cannot be read aloud yet.",null)
B.o=new A.c2(null)
B.p=new A.c3(null)
B.r=t([],u.V)
B.t=t([],u.E)
B.q=t([],u.X)
B.i=t([],u.b)
B.u={}
B.w=new A.aL(B.u,0,A.cG("aL<d>"))
B.v=A.hH("k")})();(function staticFields(){$.P=A.b([],u.f)
$.dK=null
$.dy=null
$.dx=null
$.cl=A.b([],A.cG("i<o<k>?>"))})();(function lazyInitializers(){var t=hunkHelpers.lazyFinal
t($,"hJ","eq",()=>A.ed("_$dart_dartClosure"))
t($,"hI","ds",()=>A.ed("_$dart_dartClosure_dartJSInterop"))
t($,"i3","eI",()=>A.b([new J.by()],A.cG("i<b1>")))
t($,"hL","er",()=>A.a2(A.cf({
toString:function(){return"$receiver$"}})))
t($,"hM","es",()=>A.a2(A.cf({$method$:null,
toString:function(){return"$receiver$"}})))
t($,"hN","et",()=>A.a2(A.cf(null)))
t($,"hO","eu",()=>A.a2(function(){var $argumentsExpr$="$arguments$"
try{null.$method$($argumentsExpr$)}catch(s){return s.message}}()))
t($,"hR","ex",()=>A.a2(A.cf(void 0)))
t($,"hS","ey",()=>A.a2(function(){var $argumentsExpr$="$arguments$"
try{(void 0).$method$($argumentsExpr$)}catch(s){return s.message}}()))
t($,"hQ","ew",()=>A.a2(A.dP(null)))
t($,"hP","ev",()=>A.a2(function(){try{null.$method$}catch(s){return s.message}}()))
t($,"hU","eA",()=>A.a2(A.dP(void 0)))
t($,"hT","ez",()=>A.a2(function(){try{(void 0).$method$}catch(s){return s.message}}()))
t($,"i_","bY",()=>A.ek(B.v))
t($,"hX","eD",()=>A.z("^(chapter|ch\\.|prologue|epilogue|part|book|volume|\u7b2c)\\s*[\\divxlc\u96f6\u4e00\u4e8c\u4e09\u56db\u4e94\u516d\u4e03\u516b\u4e5d\u5341\u767e\u5343]*",!1))
t($,"i4","du",()=>A.z('[.!?\u2026:;"\u201d\u2019)\\]]$',!0))
t($,"i0","eG",()=>A.z("^(chapter|ch\\.|prologue|epilogue|part|book|volume|interlude|afterword|\u7b2c)(\\s+[\\w\u4e00\u4e8c\u4e09\u56db\u4e94\u516d\u4e03\u516b\u4e5d\u5341\u767e]+)?\\s*([:.\\-\u2013\u2014]\\s*.{0,60})?$",!1))
t($,"i5","eJ",()=>A.z('[.!?\u2026:;"\u201d\u2019)\\]}]$',!0))
t($,"hZ","eF",()=>A.z("^(\\d{1,4}\\s*[|\u2022\xb7]\\s*.{1,40}|.{1,40}\\s*[|\u2022\xb7]\\s*\\d{1,4}|(page\\s*)?\\d{1,4}(\\s*(of|/)\\s*\\d+)?)$",!1))
t($,"hW","eC",()=>A.z("^(\\d{1,4}\\s+[A-Z][A-Z .&'\u2019-]{2,40}|[A-Z][A-Z .&'\u2019-]{2,40}\\s+\\d{1,4})$",!0))
t($,"hV","eB",()=>A.z("[A-Zbdfhkl0-9]",!0))
t($,"hY","eE",()=>A.z("[gjpqy]",!0))
t($,"i2","eH",()=>A.z("[a-z]",!0))
t($,"i1","dt",()=>A.z("^(#{1,3}) ",!0))})();(function nativeSupport(){!function(){var t=function(a){var n={}
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
var t=A.hs
if(typeof dartMainRunner==="function"){dartMainRunner(t,[])}else{t([])}})})()
//# sourceMappingURL=pdfbook.js.map
