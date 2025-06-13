/// <reference path="../pb_data/types.d.ts" />
migrate((app) => {
  const collection = app.findCollectionByNameOrId("pbc_1906970480")

  // add field
  collection.fields.addAt(13, new Field({
    "hidden": false,
    "id": "file3136074139",
    "maxSelect": 1,
    "maxSize": 0,
    "mimeTypes": [],
    "name": "songs",
    "presentable": false,
    "protected": false,
    "required": false,
    "system": false,
    "thumbs": [],
    "type": "file"
  }))

  return app.save(collection)
}, (app) => {
  const collection = app.findCollectionByNameOrId("pbc_1906970480")

  // remove field
  collection.fields.removeById("file3136074139")

  return app.save(collection)
})
