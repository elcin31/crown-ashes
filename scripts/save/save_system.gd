class_name SaveSystem
extends RefCounted
const DIRECTORY="user://saves"
const FORMAT=1
static func path(slot:int)->String:return DIRECTORY+"/slot_%d.json"%clampi(slot,0,3)
static func save_game(s,slot:int)->Dictionary:
	DirAccess.make_dir_recursive_absolute(DIRECTORY)
	s.data.rng_state=str(s.rng.state)
	var payload=JSON.stringify(s.data)
	var envelope={"format":FORMAT,"version":"0.2.0","saved_at":Time.get_datetime_string_from_system(),"date":s.date_text(),"realm":s.realm_name(int(s.data.player)),"sha256":payload.sha256_text(),"payload":payload}
	var target=path(slot);var tmp=target+".tmp";var f=FileAccess.open(tmp,FileAccess.WRITE)
	if f==null:return {"ok":false,"message":"Не удалось открыть сохранение: "+error_string(FileAccess.get_open_error())}
	f.store_string(JSON.stringify(envelope));f.flush();f.close()
	var verified=read_file(tmp)
	if not verified.ok:return {"ok":false,"message":"Проверка записи сохранения не пройдена."}
	if FileAccess.file_exists(target) and read_file(target).ok:
		if FileAccess.file_exists(target+".bak"):DirAccess.remove_absolute(target+".bak")
		var backup=DirAccess.rename_absolute(target,target+".bak")
		if backup!=OK:return {"ok":false,"message":"Не удалось сохранить резервную копию."}
	elif FileAccess.file_exists(target):DirAccess.remove_absolute(target)
	var err=DirAccess.rename_absolute(tmp,target)
	return {"ok":err==OK,"message":"Кампания сохранена." if err==OK else "Не удалось завершить запись сохранения."}
static func read_file(filename:String)->Dictionary:
	if not FileAccess.file_exists(filename):return {"ok":false,"message":"Сохранение не найдено."}
	var envelope=JSON.parse_string(FileAccess.get_file_as_string(filename))
	if not envelope is Dictionary or int(envelope.get("format",-1))!=FORMAT or not envelope.get("payload",null) is String:return {"ok":false,"message":"Неподдерживаемый формат сохранения."}
	if envelope.payload.sha256_text()!=envelope.get("sha256",""):return {"ok":false,"message":"Контрольная сумма сохранения не совпадает."}
	var payload=JSON.parse_string(envelope.payload)
	if not payload is Dictionary or not payload.has("provinces") or not payload.has("realms") or not payload.has("characters") or not payload.has("armies"):return {"ok":false,"message":"Повреждённое игровое состояние."}
	if payload.provinces.size()!=60 or int(payload.get("player",-1))<0 or int(payload.player)>=payload.realms.size():return {"ok":false,"message":"Некорректная карта сохранения."}
	return {"ok":true,"data":payload,"metadata":envelope,"message":"Кампания загружена."}
static func load_game(s,slot:int)->Dictionary:
	var loaded=read_file(path(slot))
	if not loaded.ok:loaded=read_file(path(slot)+".bak")
	if loaded.ok:s.data=loaded.data;s.rng.state=int(s.data.get("rng_state","1183"))
	return loaded
static func slots()->Array:
	var items=[]
	for slot in range(4):
		var loaded=read_file(path(slot))
		if not loaded.ok:loaded=read_file(path(slot)+".bak")
		items.append({"slot":slot,"exists":loaded.ok,"label":("%s · %s"%[loaded.metadata.realm,loaded.metadata.date]) if loaded.ok else "Пустой слот"})
	return items
static func latest_slot()->int:
	var result=-1;var latest=""
	for slot in range(4):
		var loaded=read_file(path(slot))
		if not loaded.ok:loaded=read_file(path(slot)+".bak")
		if loaded.ok and str(loaded.metadata.saved_at)>latest:latest=str(loaded.metadata.saved_at);result=slot
	return result
