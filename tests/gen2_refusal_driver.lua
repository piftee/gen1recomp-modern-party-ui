return function(game)
  local Screens=require("src.ui.Screens")
  local Battle=require("src.battle.gen2.Battle")
  local Mon=require("src.battle.gen2.Mon")
  local Save=require("src.core.gen2.Save")
  local Font=require("src.render.Font")
  local checks=0
  local fixed=os.getenv("EXPECT_MESSAGE")=="1"
  local function check(ok,label) checks=checks+1;assert(ok,label);print("[PARTY REFUSAL] "..label) end
  local function clear() while game.stack:top() do game.stack:pop() end end
  local function press(menu,key)
    local input=game.input
    game.input=setmetatable({wasPressed=function(_,k) return k==key end,isDown=function() return false end},{__index=input})
    local ok,why=pcall(menu.update,menu,0);game.input=input;assert(ok,why)
  end
  local function snapshot(menu,name,width)
    local G=love.graphics;local encoded={};local encode=Font.encode
    Font.encode=function(value,...) encoded[#encoded+1]=tostring(value);return encode(value,...) end
    menu.modernPartyWideWidth=width
    local canvas=G.newCanvas(width,144);canvas:setFilter("nearest","nearest")
    G.push("all");G.setCanvas(canvas);G.origin();G.setScissor();G.setShader();G.clear(1,1,1,1)
    local ok,why=pcall(menu.drawPanel,menu)
    Font.encode=encode;menu.modernPartyWideWidth=nil
    local big=G.newCanvas(width*4,576);G.setCanvas(big);G.clear(1,1,1,1);G.setColor(1,1,1,1);G.draw(canvas,0,0,0,4,4);G.pop()
    assert(ok,why)
    local f=assert(io.open(os.getenv("SHOT_DIR").."/"..name..".png","wb"))
    f:write(big:newImageData():encode("png"):getString());f:close()
    return table.concat(encoded,"|")
  end
  clear();game.save=Save.newGame({playerName="PICKER QA"});game.save.party={}
  for _,id in ipairs({"CYNDAQUIL","MAREEP","TOTODILE","CHIKORITA","PIDGEY","WOOPER"}) do
    game.save.party[#game.save.party+1]=assert(Mon.new(game.data,id,15))
  end
  game.save.party[1].hp=0;game.partyMenuCursor=1
  local battle=Battle.new({data=game.data,save=game.save,party=game.save.party,wild=Mon.new(game.data,"PIDGEY",5)})
  local battleScreen=Screens.push(game,"Gen2BattleState",{save=game.save,battle=battle,onDone=function() end})
  battleScreen:openParty(true);local picker=game.stack:top();picker.modernPartyLastWideWidth=256
  check(picker.modernPartyGeneration==2,"loaded mod owns the native forced party picker")
  press(picker,"a")
  check(picker.itemResult and picker.itemResult.text,"selecting the fainted lead opens the native refusal")
  local text=picker.itemResult.text
  local first=text:match("[^\n]+")
  local before=picker.index;press(picker,"down")
  check(picker.index==before,"refusal waits for acknowledgement and blocks navigation")
  for _,width in ipairs({160,256}) do
    local drawn=snapshot(picker,(fixed and "fixed" or "before").."-refusal-"..width,width)
    local visible=drawn:find(first,1,true)~=nil
    check(visible==fixed,fixed and "refusal text is visible at width "..width or "original renderer hides refusal at width "..width)
    if fixed then check(drawn:find("A/B CONTINUE",1,true),"visible acknowledgement hint at width "..width) end
  end
  press(picker,"b")
  check(picker.itemResult==nil and game.stack:top()==picker,"B clears the wait without leaving the party picker")
  press(picker,"down")
  check(picker.index==3,"Down responds immediately after B")
  press(picker,"a")
  check(game.stack:top()~=picker and battle.player==game.save.party[3],"healthy replacement is accepted by the battle engine")
  if fixed then
    battleScreen:openParty(true);picker=game.stack:top();picker.modernPartyLastWideWidth=256;picker.index=1
    press(picker,"a");press(picker,"a")
    check(picker.itemResult==nil,"A also acknowledges the visible refusal")
  end
  check(not love.window.hasFocus(),"test remained in the background")
  clear();print("[PARTY REFUSAL] PASS native "..checks)
end
