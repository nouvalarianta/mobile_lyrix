/// <reference path="../pb_data/types.d.ts" />
migrate((app) => {
  const collection = app.findCollectionByNameOrId("pbc_910879689")

  // remove field
  collection.fields.removeById("number661529450")

  return app.save(collection)
}, (app) => {
  const collection = app.findCollectionByNameOrId("pbc_910879689")

  // add field
  collection.fields.addAt(1, new Field({
    "hidden": true,
    "id": "number661529450",
    "max": null,
    "min": null,
    "name": "id_artist",
    "onlyInt": true,
    "presentable": false,
    "required": true,
    "system": false,
    "type": "number"
  }))

  return app.save(collection)
})
