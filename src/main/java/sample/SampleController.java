package sample;

import com.googlecode.objectify.ObjectifyService;
import java.time.LocalDateTime;
import java.util.stream.Collectors;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
public class SampleController {

  /**
   * index page.
   */
  @RequestMapping("/")
  public String index() {
    return "Local Date Time: " + LocalDateTime.now().toString()
        + "<ul>"
        + "<li><a href='/put'>put entity</a>"
        + "<li><a href='/get'>get entity</a>"
        + "<li><a href='/del'>del entity</a>"
        + "<li><a href='/stat'>memcache stat</a>"
        + "</ul>";
  }

  /**
   * put entity page.
   */
  @RequestMapping("/put")
  public String put() {
    ObjectifyService.ofy().save().entity(new ItemEntity("001", "name", "desc"));

    return "put: id=001, name=desc"
        + "<br/><a href='/'>top</a>";
  }

  /**
   * get entity page.
   */
  @RequestMapping("/get")
  public String get() {
    ItemEntity e = ObjectifyService.ofy().cache(true).load().type(ItemEntity.class).id("001").now();
    if (e != null) {
      return "get:" + String.format("%s: %s - %s", e.getId(), e.getName(), e.getDescription())
          + "<br/><a href='/'>top</a>";
    }

    return "no date.<br/><a href='/'>top</a>";
  }

  /**
   * delete entity page.
   */
  @RequestMapping("/del")
  public String del() {
    ItemEntity e = ObjectifyService.ofy().cache(true).load().type(ItemEntity.class).id("001").now();
    if (e != null) {
      ObjectifyService.ofy().delete().entity(e);
      return "delete: id=001"
          + "<br/><a href='/'>top</a>";
    }

    return "no date.<br/><a href='/'>top</a>";
  }

  /**
   * memcache stat page.
   */
  @RequestMapping("/stat")
  public String stat() {
    return ObjectifyService.factory().getMemcacheStats().getStats().entrySet().stream().map(e ->
        e.getKey()
            + ": hits=" + e.getValue().getHits()
            + ", miss=" + e.getValue().getMisses()
            + ", percent: " + e.getValue().getPercent()
    ).collect(Collectors.joining("<br/>"))
        + "<br/><a href='/'>top</a>";
  }

}
