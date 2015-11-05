//------------------------------------------------------------------------------
// Dijkstra on PyCoRAM (Software)
// Copyright (C) 2013, Shinya Takamaeda-Yamazaki
// License: Apache 2.0
//------------------------------------------------------------------------------

#include <stdio.h>
#include <stdlib.h>

#define MAX_NODES (128 * 1024 * 1024 + 1)
#define MAX_EDGES ((128 * 1024 * 1024 * 4) + 1)
#define MAX_INT (2147483647)

typedef struct
{
  int current_cost;
  int is_minimum_cost;
  int from_node_for_minimum_cost;
} node;

typedef struct 
{
  int from;
  int to;
  int cost;
} edge;


int number_of_edges;
int number_of_nodes;
node node_array [MAX_NODES];
edge edge_array [MAX_EDGES];
int edge_index;

//------------------------------------------------------------------------------
int find_current_shortest_node()
{
  int i;
  int current_shortest_cost = MAX_INT;
  int current_shortest_node = 0;
  
  for(i=1; i<=number_of_nodes; i++){
    node* n = &node_array[i];
    int is_minimum_cost = n->is_minimum_cost;
    if(!is_minimum_cost){
      int current_cost = n->current_cost;
      if(current_shortest_cost > current_cost){
        current_shortest_cost = current_cost;
        current_shortest_node = i;
      }
    }
  }
  return current_shortest_node;
}

//------------------------------------------------------------------------------
 void update_next_shortest_nodes()
{
  int i;
  for(i=0; i<number_of_edges; i++){
    edge* e = &edge_array[i];
    int from = e->from;
    int to = e-> to;
    int cost = e->cost;
    node* from_node  = &node_array[from]; // pointer ref
    node* to_node = &node_array[to]; // pointer ref
    int from_node_is_minimum_cost = from_node->is_minimum_cost;
    int to_node_is_minimum_cost = to_node->is_minimum_cost;

    if(from_node_is_minimum_cost){
      if(! to_node_is_minimum_cost){
        int current_cost_of_next_node = to_node->current_cost;
        int update_cost_of_next_node = from_node->current_cost + cost;

        if(update_cost_of_next_node < current_cost_of_next_node){
          node_array[to].current_cost = update_cost_of_next_node;
          node_array[to].from_node_for_minimum_cost = from;
        }
      }
    }

    /*
    if(to_node_is_minimum_cost){
      if(! from_node_is_minimum_cost){
        int current_cost_of_next_node = from_node->current_cost;
        int update_cost_of_next_node = to_node->current_cost + cost;

        if(update_cost_of_next_node < current_cost_of_next_node){
          node_array[from].current_cost = update_cost_of_next_node;
          node_array[from].from_node_for_minimum_cost = to;
        }
        
      }
    }
    */
  }
}

//------------------------------------------------------------------------------
int find_next_shortest_node()
{
  int next_shortest_node;
  update_next_shortest_nodes();
  next_shortest_node = find_current_shortest_node();
  node* n = &node_array[next_shortest_node];
  n->is_minimum_cost = 1;
  return next_shortest_node;
}

//------------------------------------------------------------------------------
int find_shortest_path(int start, int goal)
{
  int new_shortest_node = -1;
  int current_shortest_node = -1;
  if(start < 0 || goal < 0){
    return MAX_INT;
  }

  node_array[goal].current_cost = 0;
  node_array[goal].is_minimum_cost = 1;

  while(new_shortest_node != start){
    new_shortest_node = find_next_shortest_node();
    if(current_shortest_node == new_shortest_node) break;
    current_shortest_node = new_shortest_node;
    //printf("%d ", current_shortest_node);
  }

  return node_array[start].current_cost;
}

//------------------------------------------------------------------------------
int compute(int start, int goal)
{
  return find_shortest_path(start, goal);
}

//------------------------------------------------------------------------------
void walk_result(int sum_of_cost, int start, int goal)
{
  int current_node = start;
  printf("route: ");
  
  int* path = malloc(sizeof(int) * MAX_NODES);
  int pi = 0;

  while(1){
    //printf("%d, ", current_node);
    path[pi] = current_node; 
    pi++;
    if(current_node == 0) break;
    if(current_node == goal) break;
    current_node = node_array[current_node].from_node_for_minimum_cost;
  }

  int i;
  for(i=pi-1; i>=0; i--){
    //printf("%d, ", path[i]);
    printf("%d\n", path[i]);
  }

  free(path);
  
  printf("\r\n");
  printf("cost: %d", sum_of_cost);
  printf("\r\n");
}

//------------------------------------------------------------------------------
void init_node_array(int n)
{
  int i;
  for(i=0; i<=n; i++){
    node_array[i].current_cost = MAX_INT;
    node_array[i].is_minimum_cost = 0;
  }
}
  
//------------------------------------------------------------------------------
void add_edge(int from, int to, int cost)
{
  edge_array[edge_index].from = from;
  edge_array[edge_index].to = to;
  edge_array[edge_index].cost = cost;
  edge_index++;
}

//------------------------------------------------------------------------------
int main(int argc, char** argv)
{

  FILE* fp = fopen(argv[3], "r");
  if(fp == NULL){
    printf("no such file\n");
    return -1;
  }

  int start = atoi(argv[1]);
  int goal = atoi(argv[2]);

  /*
  int start, goal;
  if(fscanf(stdin, "%d %d\n", &start, &goal) != 2){
    exit(-1);    
  }
  */

  if(fscanf(fp, "%d %d\n", &number_of_nodes, &number_of_edges) != 2){
    exit(-1);
  }

  /*
  if(fscanf(stdin, "%d %d\n", &number_of_nodes, &number_of_edges) != 2){
    exit(-1);
  }
  */

  if(number_of_nodes > MAX_NODES || number_of_edges > MAX_EDGES){
    printf("Graph size exceeds the maximum memory capacity.");
    return -1;
  }

  edge_index = 0;

  int from, to, cost;

  while(fscanf(fp, "%d %d %d\n", &from, &to, &cost) == 3){
    add_edge(from, to, cost);
  }

  /*
  while(fscanf(stdin, "%d %d %d\n", &from, &to, &cost) == 3){
    add_edge(from, to, cost);
  }
  */

  printf("start:%d goal:%d\r\n", start, goal);
  printf("num_nodes:%d num_edges:%d\r\n", number_of_nodes, number_of_edges);

  int sum_of_cost;
  init_node_array(number_of_nodes);
  sum_of_cost = compute(start, goal);
  walk_result(sum_of_cost, start, goal);

  return 0;
}
