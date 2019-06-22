package sample;

import com.google.cloud.datastore.DatastoreOptions;
import com.googlecode.objectify.ObjectifyFactory;
import com.googlecode.objectify.ObjectifyFilter;
import com.googlecode.objectify.ObjectifyService;
import com.googlecode.objectify.cache.MemcacheService;
import java.io.BufferedReader;
import java.io.IOException;
import java.io.InputStreamReader;
import java.lang.reflect.InvocationTargetException;
import java.nio.charset.StandardCharsets;
import javax.servlet.ServletContextEvent;
import javax.servlet.ServletContextListener;
import org.springframework.boot.web.servlet.FilterRegistrationBean;
import org.springframework.boot.web.servlet.ServletListenerRegistrationBean;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

@Configuration
public class ObjectifyConfig {

  private static final String MEMCACHE_SERVICE
      = "com.github.takemikami.objectify.appengine.AppEngineMemcacheClientService";

  /**
   * Filter Registration.
   */
  @Bean
  public FilterRegistrationBean<ObjectifyFilter> objectifyFilterRegistration() {
    final FilterRegistrationBean<ObjectifyFilter> registration = new FilterRegistrationBean<>();
    registration.setFilter(new ObjectifyFilter());
    registration.addUrlPatterns("/*");
    registration.setOrder(1);
    return registration;
  }

  /**
   * Listner Registration.
   */
  @Bean
  public ServletListenerRegistrationBean<ObjectifyListener> listenerRegistrationBean() {
    ServletListenerRegistrationBean<ObjectifyListener> bean =
        new ServletListenerRegistrationBean<>();
    bean.setListener(new ObjectifyListener());
    return bean;
  }

  public static class ObjectifyListener implements ServletContextListener {

    @Override
    public void contextInitialized(ServletContextEvent sce) {
      String projectId = DatastoreOptions.getDefaultInstance().getProjectId();
      try {
        if (!"no_app_id".equals(projectId)) {
          ObjectifyService.init(new ObjectifyFactory(
              DatastoreOptions.getDefaultInstance().getService(),
              (MemcacheService) Class.forName(MEMCACHE_SERVICE).getDeclaredConstructor()
                  .newInstance()
          ));
        } else {
          // for local pc
          ProcessBuilder pb = new ProcessBuilder("gcloud", "config", "get-value", "project");
          Process process = pb.start();
          process.waitFor();
          BufferedReader br = new BufferedReader(
              new InputStreamReader(process.getInputStream(), StandardCharsets.US_ASCII));
          projectId = br.readLine();
          br.close();
          ObjectifyService.init(new ObjectifyFactory(
              DatastoreOptions.newBuilder().setProjectId(projectId).build().getService(),
              (MemcacheService) Class.forName(MEMCACHE_SERVICE).getDeclaredConstructor()
                  .newInstance()
          ));
        }
      } catch (ClassNotFoundException | InterruptedException | IOException | IllegalAccessException
          | InstantiationException | NoSuchMethodException | InvocationTargetException ex) {
        ex.printStackTrace();  // NOPMD
        throw new RuntimeException(ex);
      }

      // Register Entities
      ObjectifyService.register(ItemEntity.class);
    }

    @Override
    public void contextDestroyed(ServletContextEvent sce) {
    }

  }

}