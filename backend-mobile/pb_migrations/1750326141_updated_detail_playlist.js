/// <reference path="../pb_data/types.d.ts" />
migrate((app) => {
  const collection = app.findCollectionByNameOrId("pbc_1326454116")

  // update field
  collection.fields.addAt(1, new Field({
    "cascadeDelete": false,
    "collectionId": "pbc_976091127",
    "hidden": false,
    "id": "relation3615625517",
    "maxSelect": 1,
    "minSelect": 0,
    "name": "playlist_id",
    "presentable": false,
    "required": false,
    "system": false,
    "type": "relation"
  }))

  // update field
  collection.fields.addAt(4, new Field({
    "hidden": false,
    "id": "date1007109329",
    "max": "",
    "min": "",
    "name": "timestamp",
    "presentable": false,
    "required": false,
    "system": false,
    "type": "date"
  }))

  return app.save(collection)
}, (app) => {
  const collection = app.findCollectionByNameOrId("pbc_1326454116")

  // update field
  collection.fields.addAt(1, new Field({
    "cascadeDelete": false,
    "collectionId": "pbc_976091127",
    "hidden": false,
    "id": "relation3615625517",
    "maxSelect": 1,
    "minSelect": 0,
    "name": "playlist",
    "presentable": false,
    "required": false,
    "system": false,
    "type": "relation"
  }))

  // update field
  collection.fields.addAt(4, new Field({
    "hidden": false,
    "id": "date1007109329",
    "max": "",
    "min": "",
    "name": "added_at",
    "presentable": false,
    "required": false,
    "system": false,
    "type": "date"
  }))

  return app.save(collection)
})
