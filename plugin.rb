# coding: utf-8
# name: thrive-discourse
# about: discourse customizations for thrive community (currently just larger avatars)
# version: 1.0
# authors: Henri Hyyryläinen
# Large avatars stylesheet originally in wyl plugin by Jacob Chapel
# (which makes avatars big but blurry)

register_asset "stylesheets/large-avatars.css.scss", :desktop
register_asset "javascripts/discourse/initializers/bigify-avatars.js.es6"
