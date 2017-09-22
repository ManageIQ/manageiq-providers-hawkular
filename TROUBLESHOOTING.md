# Troubleshooting

## Error on rendering home page
Example error:

```
 Error caught: [ActionView::Template::Error] couldn't find file 'ui-select/dist/select' with type 'text/css'
[...]
 F, [2017-09-20T18:15:40.207925 #11506:3b05e5c] FATAL -- :     23:       %meta{"http-equiv" => "cache-control", :content => "no-cache, no-store"}
    24:
    25:       = favicon_link_tag
    26:       = stylesheet_link_tag 'application'
    27:       = render :partial => "stylesheets/template50"
    28:       = javascript_include_tag 'application'
    29:       - if Rails.env.development?
[----] F, [2017-09-20T18:15:40.207953 #11506:3b05e5c] FATAL -- :
[----] F, [2017-09-20T18:15:40.207995 #11506:3b05e5c] FATAL -- : /home/xeviknal/code/manageiq/manageiq-ui-classic/app/assets/stylesheets/application.css:30
```

It means that proper dependencies haven't been downloaded. To download them, follow the commands below:

```
cd ~/ManageIQ/manageiq-ui-classic
npm install
```
