ActionController::Routing::Routes.draw do |map|
  map.connect ':controller/:action/:id.:format'
  map.connect ':controller/:action/:id', :controller => 'link'
end
