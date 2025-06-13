/// <reference path="../pb_data/types.d.ts" />
migrate((app) => {
  const collection = app.findCollectionByNameOrId("pbc_1906970480")

  // remove field
  collection.fields.removeById("url2420893113")

  // remove field
  collection.fields.removeById("file3136074139")

  // add field
  collection.fields.addAt(12, new Field({
    "hidden": false,
    "id": "file2420893113",
    "maxSelect": 1,
    "maxSize": 0,
    "mimeTypes": [],
    "name": "audioUrl",
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

  // add field
  collection.fields.addAt(12, new Field({
    "exceptDomains": null,
    "hidden": false,
    "id": "url2420893113",
    "name": "audioUrl",
    "onlyDomains": null,
    "presentable": false,
    "required": false,
    "system": false,
    "type": "url"
  }))

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

  // remove field
  collection.fields.removeById("file2420893113")

  return app.save(collection)
})
