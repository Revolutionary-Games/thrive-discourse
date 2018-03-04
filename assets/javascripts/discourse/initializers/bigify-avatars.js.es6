export default {
    name: 'bigify-avatars',
    initialize() {
        if (window.MutationObserver) {

            let re = new RegExp("^(.*)/user_avatar/(.*)/45/(.*)$");

            let observer = new MutationObserver(function (mutations) {
                mutations.forEach(function (mutation) {
                    mutation.addedNodes.forEach(function (node) {
                        // Skip non-images
                        if (typeof node.getElementsByTagName !== 'function') {
                            return;
                        }

                        let imgs = node.getElementsByTagName('img');
                        
                        // for every new image
                        for(let i = 0; i < imgs.length; ++i){
                            
                            let img = imgs[i];

                            let match = re.exec(img.src);

                            if(match){
                                img.src = match[1] + "/user_avatar/" + match[2] + "/120/" +
                                    match[3];
                            }
                        }
                    });
                });
            });

            // Bind to document root to see everything
            observer.observe(document.documentElement, {childList: true, subtree: true});
        }
  }
};
