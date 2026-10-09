local p=assert(data.raw.ammo["nuclear-accumulator"])
assert(p.stack_size==1 and p.magazine_size==36001)
local not_stackable=false
for _,flag in ipairs(p.flags or {}) do if flag=="not-stackable" then not_stackable=true end end
assert(not_stackable,"test requires actual not-stackable prototype flag")
log("NA PROTOTYPE PASS: stack_size=1, magazine_size=36001, not-stackable flag verified")
